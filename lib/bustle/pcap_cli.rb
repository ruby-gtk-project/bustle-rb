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
    # What g_option_context_get_help(context, FALSE, NULL) prints for
    # upstream's two option groups, byte for byte: the summary, then the bus
    # group it added before the main one, descriptions in a column 20
    # characters wide, and a blank line at the end. Upstream disables GLib's
    # own --help so that both groups show, which is why the help text has no
    # "Help Options:" section of its own.
    USAGE = <<~USAGE
      Usage:
        bustle-pcap [OPTION…] FILENAME

      Logs D-Bus traffic to FILENAME in a format suitable for bustle

      Bus Options:
        -e, --session     Monitor session bus (default)
        -y, --system      Monitor system bus
        -a, --address     Monitor given D-Bus address

      Application Options:
        -v, --verbose     Print brief summaries of captured messages to stdout
        -q, --quiet       Don't print out instructions
        -V, --version     Print version information and exit
        -h, --help        Print help and exit

    USAGE

    VERSION_NOTICE = <<~NOTICE
      bustle-pcap #{Bustle::Rb::VERSION}

      Copyright © 2011–2018 Will Thompson <will@willthompson.co.uk>
      This is free software; see the source for copying conditions.  There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

      Written by Will Thompson <will@willthompson.co.uk>
    NOTICE

    USAGE_EXIT_STATUS = 2

    # Upstream's two GOptionEntry tables, bus group first, each entry's long
    # and short spelling under the name the C file gives its variable.
    Option = Struct.new(:name, :long, :short)

    OPTIONS = [
      Option.new(:session, "--session", "-e"),
      Option.new(:system, "--system", "-y"),
      Option.new(:address, "--address", "-a"),
      Option.new(:verbose, "--verbose", "-v"),
      Option.new(:quiet, "--quiet", "-q"),
      Option.new(:version, "--version", "-V"),
      Option.new(:help, "--help", "-h"),
    ].freeze

    # --address is upstream's one G_OPTION_ARG_STRING; the rest are
    # G_OPTION_ARG_NONE switches, which take nothing.
    ARGUMENT_OPTIONS = [:address].freeze

    OPTION_TERMINATOR = "--"

    class << self
      def run(argv, output: $stdout, errors: $stderr) = new(argv, output:, errors:).run
    end

    def initialize(argv, output: $stdout, errors: $stderr)
      @argv = argv
      @output = output
      @errors = errors
      @switches = {}
      @address = nil
      @filenames = []
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

      # GOption's grammar, which is not quite anyone else's. Long options must
      # be spelled in full — GLib has no abbreviations — and take their
      # argument after a `=` or as the next word. Short options bundle, and a
      # bundle containing one that takes an argument takes the next word for
      # it wherever in the bundle it appears, so `-qa ADDRESS` and
      # `-aq ADDRESS` both work. `--` ends the options. Everything else is a
      # filename, including a bare `-`. The first thing GLib cannot parse
      # stops the parse.
      def parse
        @arguments = @argv.dup
        until @arguments.empty? || @invalid
          take(@arguments.shift)
        end
      end

      def take(argument)
        case
        when argument == OPTION_TERMINATOR then @filenames.concat(@arguments.slice!(0, @arguments.length))
        when argument.start_with?("--") then take_long(argument)
        when argument.start_with?("-") && argument.length > 1 then take_short(argument)
        else @filenames << argument
        end
      end

      def take_long(argument)
        argument.split("=", 2).then do |spelling, attached|
          OPTIONS.find { |option| option.long == spelling }.then do |option|
            if option
              apply(option, argument, attached)
            else
              @invalid = "Unknown option #{argument}"
            end
          end
        end
      end

      # Every character in the bundle is an option of its own; the token as a
      # whole is what GLib names in its complaint about any of them.
      def take_short(argument)
        argument[1..].each_char do |letter|
          OPTIONS.find { |option| option.short == "-#{letter}" }.then do |option|
            if option
              apply(option, "-#{letter}", nil)
            else
              @invalid = "Unknown option #{argument}"
            end
          end
        end
      end

      # A switch is set however it was spelled, `--session=whatever`
      # included; an option that takes an argument gets the text after its
      # `=`, or the next word, or a complaint.
      def apply(option, spelling, attached)
        if ARGUMENT_OPTIONS.include?(option.name)
          take_argument(option, spelling, attached || @arguments.shift)
        else
          @switches[option.name] = true
        end
      end

      def take_argument(option, spelling, value)
        case
        when !@invalid.nil? then nil
        when value.nil? then @invalid = "Missing argument for #{spelling}"
        when option.name == :address then @address = value
        end
      end

      # Upstream checks these in this order: a parse error outranks even
      # --help, and then --help and --version win over everything, including a
      # missing filename.
      def complaint
        if @invalid
          @invalid
        elsif help? || version?
          nil
        elsif buses_specified > 1
          "You may only specify one of --session, --system and --address"
        elsif @filenames.length != 1
          "You must specify exactly one output filename"
        end
      end

      # Upstream's `!!session_specified + !!system_specified + !!address`:
      # each of the three counts once however many times it was given, so
      # `-e -e` is one bus and `-e -y` is two.
      def buses_specified = [session?, system?, !@address.nil?].count(true)

      def session? = @switches.fetch(:session, false)

      def system? = @switches.fetch(:system, false)

      def verbose? = @switches.fetch(:verbose, false)

      def quiet? = @switches.fetch(:quiet, false)

      def version? = @switches.fetch(:version, false)

      def help? = @switches.fetch(:help, false)

      def dispatch
        if help?
          @output.print(USAGE)
          0
        elsif version?
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

      # Upstream's precedence: an address beats --system, and --session is
      # the default whether it was asked for or not.
      def target
        case
        when @address then Monitor.target_for(@address)
        when system? then Monitor::SYSTEM_BUS
        else Monitor::SESSION_BUS
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
        unless quiet?
          @output.puts("Logging D-Bus traffic to '#{filename}'...")
          @output.puts("Hit Control-C to stop logging.")
        end
      end

      # Upstream's message_logged_cb, which prints sender, destination,
      # message type and member for each captured message.
      def summarise(_timestamp, body)
        if verbose?
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
