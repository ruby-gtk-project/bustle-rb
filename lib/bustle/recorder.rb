# frozen_string_literal: true

require "adwaita"

require_relative "loader"
require_relative "monitor"
require_relative "pcap_loader"
require_relative "renderer"
require_relative "translation"
require_relative "util"

module Bustle
  # Drives a Monitor and feeds what it records into the diagram as it arrives.
  #
  # Ported from upstream's Bustle/UI/Recorder.hs together with the recording
  # half of Bustle/UI.hs — `startRecording`, `recorderRun`, `processBatch`,
  # `aChallengerAppears` and `finishedRecording`, which only live in UI.hs
  # because upstream's recorder has nowhere else to put them — upstream's own
  # comment on `recorderChooseFile` says it "shouldn't be here".
  #
  # The shape is upstream's. Frames are written to a temporary file in the
  # cache directory, so a recording exists on disk before anyone decides where
  # to keep it. Each message is unmarshalled by the same Converter the file
  # loader uses, filtered by the same Loader.relevant? test, and queued. Every
  # 200ms the queue is handed to Renderer.process_some, whose output is merged
  # onto everything rendered so far — which is what Result#merge is for, and
  # why the renderer's incremental path has to agree with its all-at-once one.
  #
  # A batch that produced no shapes does not count as a message from the
  # user's point of view, so the counter in the subtitle only moves when the
  # diagram does. That is upstream's rule, comment and all.
  class Recorder
    # Upstream's timeoutAdd interval, in milliseconds.
    BATCH_INTERVAL = 200

    EXTENSION = ".bustle"

    # Upstream names the temp file after the current local time with the
    # fractional seconds chopped off (`takeWhile (/= '.') (show zonedTime)`).
    TIMESTAMP_FORMAT = "%Y-%m-%d %H:%M:%S"

    class << self
      # Upstream's recorderChooseFile: a save chooser pre-filled with the
      # temporary file's own name, which is a timestamp and therefore already
      # a reasonable suggestion.
      def choose_file(name:, parent:, &on_chosen)
        save_dialog(name).then do |chooser|
          chooser.save(parent, nil) do |_source, result|
            on_chosen.call(chooser.save_finish(result).path)
          rescue GLib::Error
            # The user dismissed the chooser, which is not an error.
            nil
          end
        end
      end

      private

        def save_dialog(name)
          Gtk::FileDialog.new.tap do |chooser|
            chooser.modal = true
            chooser.initial_name = name
          end
        end
    end

    # `on_progress` is handed the message count and the merged renderer result
    # so far; `on_finished` the temporary path and whether anything was
    # recorded; `on_error` a title for the error bar.
    def initialize(target:, on_progress:, on_finished:, on_error:)
      @target = target
      @on_progress = on_progress
      @on_finished = on_finished
      @on_error = on_error
      @converter = PcapLoader::Converter.new
      @state = Renderer.state_new
      @result = Renderer::Result.empty
      @pending = []
      @count = 0
    end

    attr_reader :count

    # Where the recording is being written. Nothing moves it until the user
    # picks a permanent home for it.
    def path
      @path ||= File.join(Util.cache_dir, "#{Time.now.strftime(TIMESTAMP_FORMAT)}#{EXTENSION}")
    end

    # Upstream's "Recording session bus…", as markup, because the subtitle
    # beside it is markup too.
    def title = format(Bustle._("Recording %s&#8230;"), Monitor.describe(@target))

    def start
      monitor.tap do |recording|
        recording.signal_connect(Monitor::MESSAGE_LOGGED) { |timestamp, body| receive(timestamp, body) }
        recording.signal_connect(Monitor::STOPPED) { |domain, code, message| conclude(domain, code, message) }
        recording.start
        unless recording.stopped?
          GLib::Timeout.add(BATCH_INTERVAL) { tick }
        end
      end
      self
    end

    def stop = monitor.stop

    def monitor = @monitor ||= Monitor.new(target: @target, filename: path)

    private

      # One turn of upstream's processor: drain the pipe, then render whatever
      # that produced. Returning false takes the timeout off the main loop,
      # which is what upstream's timeoutRemove does by hand.
      def tick
        monitor.pump
        process_batch
        !monitor.stopped?
      end

      def receive(timestamp, body)
        @converter.convert(timestamp, body).then do |message|
          case message
          when String then Util.warn(message)
          else queue(message)
          end
        end
      end

      # The live recorder filters each message as it arrives, where the file
      # loader filters the whole log at once; the test is the same one.
      def queue(message)
        if Loader.relevant?(message.event)
          @pending << message
        end
      end

      def process_batch
        @pending.then do |pending|
          @pending = []
          unless pending.empty?
            render(pending)
          end
        end
      end

      def render(pending)
        Renderer.process_some(pending, [], @state).first.then do |batch|
          @result = @result.merge(batch)
          unless batch.shapes.empty?
            @count += pending.length
            @on_progress.call(@count, @result)
          end
        end
      end

      # Upstream swallows exactly one error here: the cancellation its own
      # Stop button caused. Everything else reaches the error bar.
      def conclude(domain, code, message)
        process_batch
        unless domain == Monitor::IO_ERROR_QUARK && code == Monitor::IO_ERROR_CANCELLED
          @on_error.call(message)
        end
        @on_finished.call(path, @count.positive?)
      end
  end
end
