# frozen_string_literal: true

require "glib2"

require_relative "noninteractive"
require_relative "translation"

module Bustle
  # The command line.
  #
  # Ported from upstream's Bustle.hs, and the argument half of
  # Bustle/UI.hs's uiMain: the batch modes each take exactly one log and
  # print to stdout, --pair takes two logs to draw side by side, anything
  # else is a list of logs to open, and --debug asks the canvas to draw its
  # bounding boxes. Upstream's comment says it wants a real option parser;
  # this is still not one, because the grammar is small enough that matching
  # on it is clearer.
  #
  # Matching is the operative word. Upstream matches the whole argument list
  # against ["--help"], so a --help anywhere else is a log name; it strips
  # exactly "--debug" and hands every other token, "--nonesuch" included, to
  # the loader, which reports it as a log it could not read; and its runOne
  # takes the arguments after a batch mode and insists there be exactly one,
  # so `--count --debug log` is a usage error rather than a count.
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

    DEBUG_FLAG = "--debug"

    PAIR_FLAG = "--pair"

    # Upstream's mainB matches ["--pair", session, system] and nothing else:
    # a --pair with the wrong number of logs after it is not a usage error,
    # it is a list of logs with a silly name in it.
    PAIR_LENGTH = 3

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
      GLib.application_name = Bustle._("Bustle")
      case command
      when :help then usage(fatal: false)
      when :batch then run_batch
      when :pair then launch([], arguments.drop(1))
      else launch(arguments, nil)
      end
    end

    private

      def command
        case
        when @argv == ["--help"] then :help
        when BATCH_MODES.key?(@argv.first) then :batch
        when arguments.length == PAIR_LENGTH && arguments.first == PAIR_FLAG then :pair
        else :interactive
        end
      end

      # A batch mode takes exactly one argument — whatever it is, flag or
      # not — and anything else is a usage error, as upstream's runOne makes
      # it. --debug is not stripped here, because upstream strips it inside
      # uiMain and a batch run never gets that far.
      def run_batch
        if batch_arguments.length == 1
          batch_result
        else
          usage(fatal: true)
        end
      end

      def batch_arguments = @argv.drop(1)

      def batch_result
        if Noninteractive.public_send(BATCH_MODES.fetch(@argv.first), batch_arguments.first)
          0
        else
          1
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

      # Upstream's `filter (not . isDebug) args`: --debug goes, everything
      # else stays, so a mistyped flag reaches the loader and is reported as
      # the log it could not read.
      def arguments = @argv.reject { |argument| argument == DEBUG_FLAG }

      def debug? = @argv.include?(DEBUG_FLAG)
  end
end
