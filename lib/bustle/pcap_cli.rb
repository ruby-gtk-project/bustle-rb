# frozen_string_literal: true

require_relative "monitor"
require_relative "pcap_loader"
require_relative "rb/version"

module Bustle
  # The standalone command-line recorder.
  #
  # Ported from upstream's c-sources/bustle-pcap.c, a small binary built
  # beside the GUI: it drives the same monitor headlessly, writes the pcap log
  # the viewer reads, prints the two lines of instructions the welcome page
  # and the appdata both point users at, and stops on Control-C.
  #
  # The options are upstream's, short forms included: one of -e/--session (the
  # default), -y/--system or -a/--address ADDRESS, plus -v/--verbose,
  # -q/--quiet, -V/--version and -h/--help, and exactly one output filename.
  # Specifying two buses, or no filename, or two filenames, is an error with
  # exit status 2, as upstream's parse_arguments makes it.
  #
  # Upstream's --verbose summary is produced by GDBusMessage; the port
  # unmarshals the same blob with its own Unmarshaller, which is what the
  # viewer does with the frames it reads back off disk.
  class PcapCli
    USAGE = <<~USAGE
      Usage:
        bustle-pcap [OPTION…] FILENAME

      Logs D-Bus traffic to FILENAME in a format suitable for bustle

      Help Options:
        -h, --help       Print help and exit

      Application Options:
        -v, --verbose    Print brief summaries of captured messages to stdout
        -q, --quiet      Don't print out instructions
        -V, --version    Print version information and exit

      Bus Options:
        -e, --session    Monitor session bus (default)
        -y, --system     Monitor system bus
        -a, --address    Monitor given D-Bus address
    USAGE

    VERSION_NOTICE = <<~NOTICE
      bustle-pcap #{Bustle::Rb::VERSION}

      Copyright © 2011–2018 Will Thompson <will@willthompson.co.uk>
      This is free software; see the source for copying conditions.  There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

      Written by Will Thompson <will@willthompson.co.uk>
    NOTICE

    USAGE_EXIT_STATUS = 2

    BUS_FLAGS = {
      "-e"        => Monitor::SESSION_BUS,
      "--session" => Monitor::SESSION_BUS,
      "-y"        => Monitor::SYSTEM_BUS,
      "--system"  => Monitor::SYSTEM_BUS,
    }.freeze

    ADDRESS_FLAGS = ["-a", "--address"].freeze
    VERBOSE_FLAGS = ["-v", "--verbose"].freeze
    QUIET_FLAGS = ["-q", "--quiet"].freeze
    VERSION_FLAGS = ["-V", "--version"].freeze
    HELP_FLAGS = ["-h", "--help"].freeze

    class << self
      def run(argv, output: $stdout, errors: $stderr) = new(argv, output:, errors:).run
    end

    def initialize(argv, output: $stdout, errors: $stderr)
      @argv = argv
      @output = output
      @errors = errors
      @buses = []
      @address = nil
      @filenames = []
      @verbose = false
      @quiet = false
      @version = false
      @help = false
      @invalid = nil
      @status = 0
    end

    def run
      parse
      case complaint
      when nil then dispatch
      else usage_error(complaint)
      end
    end

    private

      def parse
        arguments = @argv.dup
        until arguments.empty?
          take(arguments.shift, arguments)
        end
      end

      def take(argument, rest)
        case argument
        when *BUS_FLAGS.keys then @buses << BUS_FLAGS.fetch(argument)
        when *ADDRESS_FLAGS then @address = rest.shift
        when *VERBOSE_FLAGS then @verbose = true
        when *QUIET_FLAGS then @quiet = true
        when *VERSION_FLAGS then @version = true
        when *HELP_FLAGS then @help = true
        else classify(argument)
        end
      end

      def classify(argument)
        if argument.start_with?("-")
          @invalid = "Unknown option #{argument}"
        else
          @filenames << argument
        end
      end

      # Upstream checks these in this order, and --help and --version win
      # over everything, including a missing filename.
      def complaint
        if @help || @version
          nil
        elsif @invalid
          @invalid
        elsif buses_specified > 1
          "You may only specify one of --session, --system and --address"
        elsif @filenames.length != 1
          "You must specify exactly one output filename"
        end
      end

      def buses_specified = @buses.length + (@address ? 1 : 0)

      def dispatch
        if @help
          @output.print(USAGE)
          0
        elsif @version
          @output.print(VERSION_NOTICE)
          0
        else
          record
        end
      end

      def usage_error(message)
        @errors.puts(message)
        @errors.print(USAGE)
        USAGE_EXIT_STATUS
      end

      def target
        if @address
          Monitor.target_for(@address)
        else
          @buses.first || Monitor::SESSION_BUS
        end
      end

      def filename = @filenames.first

      def record
        monitor.tap do |recording|
          announce
          trap("INT") { recording.stop }
          recording.start
          recording.run
        end
        @status
      end

      def monitor
        @monitor ||= Monitor.new(target:, filename:).tap do |recording|
          recording.signal_connect(Monitor::MESSAGE_LOGGED) { |timestamp, body| summarise(timestamp, body) }
          recording.signal_connect(Monitor::STOPPED) { |domain, code, message| report(domain, code, message) }
        end
      end

      def announce
        unless @quiet
          @output.puts("Logging D-Bus traffic to '#{filename}'...")
          @output.puts("Hit Control-C to stop logging.")
        end
      end

      # Upstream's message_logged_cb, which prints sender, destination,
      # message type and member for each captured message.
      def summarise(_timestamp, body)
        if @verbose
          describe(body).then { |line| @output.puts(line) }
        end
      end

      def describe(body)
        PcapLoader::Unmarshaller.new(body).message.then do |message|
          "#{message.sender} -> #{message.destination}: #{message.type} #{message.member}"
        end
      rescue PcapLoader::Unmarshaller::Error => e
        "Warning: #{e.message}"
      end

      # Upstream's stopped_cb: a cancellation is the user pressing Control-C
      # and is not an error; anything else is.
      def report(domain, code, message)
        unless domain == Monitor::IO_ERROR_QUARK && code == Monitor::IO_ERROR_CANCELLED
          @errors.print("Error: #{domain} #{code} #{message}")
          @status = 1
        end
      end
  end
end
