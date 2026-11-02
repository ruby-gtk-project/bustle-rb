# frozen_string_literal: true

require_relative "noninteractive"
require_relative "translation"

module Bustle
  # The command line.
  #
  # Ported from upstream's Bustle.hs: the batch modes each take exactly one
  # log and print to stdout, --pair takes two logs to draw side by side,
  # anything else is a list of logs to open, and --debug asks the canvas to
  # draw its bounding boxes. Upstream's comment says it wants a real option
  # parser; this is still not one, because the grammar is small enough that
  # matching on it is clearer.
  class Main
    USAGE = <<~USAGE
      Usage:
        bustle [LOGFILE [...]]
        bustle --pair SESSION_LOGFILE SYSTEM_LOGFILE

      Or for batch-processing:
        bustle --count LOGFILE
        bustle --time LOGFILE
        bustle --dot LOGFILE
    USAGE

    BATCH_MODES = {
      "--count" => :run_count,
      "--time"  => :run_time,
      "--dot"   => :run_dot,
    }.freeze

    class << self
      # Returns a process exit status, so the executable can hand it straight
      # to exit.
      def run(argv)
        new(argv).run
      end
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      Translation.init
      case command
      when :help then usage(fatal: false)
      when :batch then run_batch
      when :pair then run_ui(pair: logs)
      else run_ui(logs:)
      end
    end

    private

      def command
        if @argv.include?("--help")
          :help
        elsif BATCH_MODES.key?(@argv.first)
          :batch
        elsif @argv.first == "--pair"
          :pair
        else
          :interactive
        end
      end

      # A batch mode takes exactly one log; anything else is a usage error,
      # as upstream's runOne makes it.
      def run_batch
        if logs.length == 1
          batch_result
        else
          usage(fatal: true)
        end
      end

      def batch_result
        if Noninteractive.public_send(BATCH_MODES.fetch(@argv.first), logs.first)
          0
        else
          1
        end
      end

      def run_ui(logs: [], pair: nil)
        if pair && pair.length != 2
          usage(fatal: true)
        else
          launch(logs, pair)
        end
      end

      # The widgets are required here and nowhere else, so the batch modes
      # and `require "bustle"` never load GTK, Libadwaita or Cairo.
      def launch(logs, pair)
        require_relative "application"
        Application.new(logs:, pair:, show_bounds: debug?).build.run
        0
      end

      def usage(fatal:)
        $stderr.puts(USAGE)
        if fatal
          1
        else
          0
        end
      end

      # Everything that is not a flag: the logs to open or analyse.
      def logs = @argv.reject { |argument| argument.start_with?("--") }

      def debug? = @argv.include?("--debug")
  end
end
