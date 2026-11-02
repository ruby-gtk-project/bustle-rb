# frozen_string_literal: true

require "open3"

require_relative "pcap_loader"

module Bustle
  # Records D-Bus traffic into a pcap log, a message at a time.
  #
  # Ported from upstream's Bustle/Monitor.hs and the C GObject it binds,
  # c-sources/pcap-monitor.c. Upstream's monitor does three things: it spawns
  # `dbus-monitor --pcap` (behind `pkexec` for the system bus, behind
  # `flatpak-spawn --host` inside a sandbox), it reads that subprocess's
  # stdout as a pcap stream with libpcap and copies every frame into the
  # output file with pcap_dump(), and it emits `message-logged` per frame and
  # `stopped` once. It also owns a well-known name on the bus so the viewer
  # can hide the monitor's own traffic, which this port does not: that needs a
  # D-Bus connection of its own, and the name is only a hint to the viewer.
  #
  # So this is the same subprocess supervisor with the libpcap half written in
  # Ruby. The output file is byte-for-byte what dbus-monitor wrote, because
  # every chunk read off the pipe is appended to it verbatim before being
  # parsed — the stream and the file are the same pcap format, which is why
  # upstream can pcap_dump() frames straight back out.
  #
  # The two signals are upstream's, under upstream's names:
  #
  #   message-logged(timestamp_microseconds, marshalled_message)
  #   stopped(domain, code, message)
  #
  # Nothing here touches GTK or the GLib main loop, so the same object drives
  # the recorder (pumped from a GLib timeout) and `exe/bustle-pcap` (pumped
  # from a blocking loop). #pump never blocks; #run does.
  class Monitor
    SESSION_BUS = :session
    SYSTEM_BUS = :system

    MESSAGE_LOGGED = "message-logged"
    STOPPED = "stopped"

    # Upstream's `stopped` handler ignores one particular error — a stop the
    # user asked for — by comparing the domain and code GLib would have used,
    # so the port reports a user-initiated stop under the same pair.
    # G_IO_ERROR_CANCELLED is 19 and G_IO_ERROR_FAILED is 0 in GLib's
    # GIOErrorEnum.
    IO_ERROR_QUARK = "g-io-error-quark"
    IO_ERROR_FAILED = 0
    IO_ERROR_CANCELLED = 19

    READ_SIZE = 64 * 1024

    # How long #run waits for the pipe before looking at its own flags again.
    POLL_INTERVAL = 0.2

    class << self
      # Upstream's BusType, as the recorder's three menu items name it: the
      # session bus, the system bus, or a literal address.
      def target_for(bus_or_address)
        case bus_or_address
        when SESSION_BUS, SYSTEM_BUS then bus_or_address
        else bus_or_address.to_s
        end
      end

      # Upstream's "Recording %s…" fills in one of these.
      def describe(target)
        case target
        when SESSION_BUS then "session bus"
        when SYSTEM_BUS then "system bus"
        else target.to_s
        end
      end
    end

    def initialize(target:, filename:)
      @target = target
      @filename = filename
      @handlers = {MESSAGE_LOGGED => [], STOPPED => []}
      @buffer = +""
      @byte_order = nil
      @started = false
      @stopped = false
      @cancelled = false
    end

    attr_reader :filename, :target

    # Named after the GObject method, because these are GObject signals
    # upstream and the recorder connects to them by upstream's names.
    def signal_connect(name, &handler)
      @handlers.fetch(name) << handler
      self
    end

    # Spawns the subprocess and opens the log. A failure to start is reported
    # as `stopped`, which is what upstream's `newFailed` handler turns a
    # GError from monitorNew into.
    def start
      @started = true
      @output = File.open(@filename, "wb")
      @input, @pipe, @errors, @process = Open3.popen3(*argv)
      @input.close
      self
    rescue SystemCallError, IOError => e
      stop_with(IO_ERROR_FAILED, "Failed to start dbus-monitor: #{e.message}")
      self
    end

    # Reads whatever the subprocess has written since the last call and emits
    # one message-logged per complete frame. Returns false once the monitor
    # has stopped, so a GLib timeout can use it as its callback directly.
    def pump
      if @stopped
        false
      else
        drain
        !@stopped
      end
    end

    # The blocking equivalent, for the command-line recorder: pump until the
    # subprocess goes away or #stop is called.
    def run
      until @stopped
        IO.select(
          [@pipe],
          nil,
          nil,
          POLL_INTERVAL,
        )
        pump
      end
      self
    end

    # Upstream's bustle_pcap_monitor_stop(): ask the subprocess to go away and
    # let the next pump flush what is left in the pipe before `stopped` fires.
    def stop
      @cancelled = true
      terminate
      self
    end

    def stopped? = @stopped

    private

      def argv
        [].tap do |args|
          if sandboxed?
            args.push("flatpak-spawn", "--host")
          end
          if @target == SYSTEM_BUS
            args.push("pkexec")
          end
          args.push("dbus-monitor", "--pcap")
          args.concat(bus_arguments)
        end
      end

      def bus_arguments
        case @target
        when SESSION_BUS then ["--session"]
        when SYSTEM_BUS then ["--system"]
        else ["--address", @target.to_s]
        end
      end

      # Inside a Flatpak sandbox dbus-monitor has to run on the host, which is
      # the file upstream's monitor tests for too.
      def sandboxed? = File.exist?("/.flatpak-info")

      def drain
        read_available.then do |chunk|
          case chunk
          when nil then finish
          when "" then nil
          else consume(chunk)
          end
        end
      end

      # "" when the pipe has nothing ready, nil at end of file.
      def read_available
        @pipe.read_nonblock(READ_SIZE)
      rescue IO::WaitReadable
        ""
      rescue EOFError, IOError
        nil
      end

      def consume(chunk)
        @output.write(chunk)
        @output.flush
        @buffer << chunk.b
        unless read_global_header || @stopped
          emit_frames
        end
      end

      # Returns true while the 24-byte pcap header has not arrived in full.
      def read_global_header
        if @byte_order
          false
        elsif @buffer.bytesize < PcapLoader::GLOBAL_HEADER_SIZE
          true
        else
          parse_global_header
          false
        end
      end

      def parse_global_header
        @buffer.slice!(0, PcapLoader::GLOBAL_HEADER_SIZE).then do |header|
          @byte_order = byte_order_of(header)
          link_type = unpack_word(header[20, 4])
          unless [PcapLoader::LINK_TYPE_NULL, PcapLoader::LINK_TYPE_DBUS].include?(link_type)
            stop_with(IO_ERROR_FAILED, "Incorrect link type #{link_type}")
          end
        end
      end

      def byte_order_of(header)
        case header[0, 4].unpack1("H8")
        when "d4c3b2a1" then :little
        when "a1b2c3d4" then :big
        else
          stop_with(IO_ERROR_FAILED, "Couldn't read messages from dbus-monitor: not a pcap stream")
          :little
        end
      end

      def unpack_word(bytes) = bytes.unpack1(@byte_order == :big ? "N" : "V")

      # One frame is a 16-byte header (seconds, microseconds, captured length,
      # original length) and then that many bytes of marshalled message.
      def emit_frames
        while (frame = next_frame)
          emit(MESSAGE_LOGGED, frame.first, frame.last)
        end
      end

      def next_frame
        if @buffer.bytesize < PcapLoader::PACKET_HEADER_SIZE
          nil
        else
          frame_of(@buffer.unpack(@byte_order == :big ? "N4" : "V4"))
        end
      end

      def frame_of(header)
        seconds, microseconds, captured, _original = header
        if @buffer.bytesize < PcapLoader::PACKET_HEADER_SIZE + captured
          nil
        else
          @buffer.slice!(0, PcapLoader::PACKET_HEADER_SIZE)
          [(seconds * 1_000_000) + microseconds, @buffer.slice!(0, captured)]
        end
      end

      def terminate
        if @process&.alive?
          Process.kill("TERM", @process.pid)
        end
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end

      # End of the pipe: the recording is over. A stop the user asked for is
      # reported as cancelled, which is the one error the recorder swallows.
      def finish
        if @cancelled
          stop_with(IO_ERROR_CANCELLED, "")
        else
          stop_with(IO_ERROR_FAILED, exit_message)
        end
      end

      # dbus-monitor's own complaint if it has one, and upstream's wording for
      # an unexplained end of stream otherwise.
      def exit_message
        diagnostics.then do |text|
          if text.empty?
            "EOF when reading from dbus-monitor"
          else
            text
          end
        end
      end

      def diagnostics
        @errors.read.to_s.strip
      rescue IOError
        ""
      end

      def stop_with(code, message)
        unless @stopped
          @stopped = true
          close
          emit(
            STOPPED,
            IO_ERROR_QUARK,
            code,
            message,
          )
        end
      end

      def close
        [@input, @pipe, @errors, @output].compact.each do |io|
          unless io.closed?
            io.close
          end
        end
        @process&.join
      rescue IOError
        nil
      end

      def emit(name, *arguments)
        @handlers.fetch(name).each { |handler| handler.call(*arguments) }
      end
  end
end
