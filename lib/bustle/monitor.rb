# frozen_string_literal: true

require "gio2"
require "open3"

require_relative "pcap_loader"
require_relative "types"

module Bustle
  # Records D-Bus traffic into a pcap log, a message at a time.
  #
  # Ported from upstream's Bustle/Monitor.hs and the C GObject it binds,
  # c-sources/pcap-monitor.c. Upstream's monitor does three things: it spawns
  # `dbus-monitor --pcap` (behind `pkexec` for the system bus, behind
  # `flatpak-spawn --host` inside a sandbox), it reads that subprocess's
  # stdout as a pcap stream with libpcap and copies every frame into the
  # output file with pcap_dump(), and it emits `message-logged` per frame and
  # `stopped` once. It also opens a second connection to the bus being
  # recorded, requests a well-known name of its own on it so the viewer can
  # hide the monitor's own traffic, and asks that bus who owns every
  # well-known name on it — see #seed_names, which is the whole reason a
  # service that was already running when the recording started is drawn
  # under its own name rather than as a bare ":1.42".
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
    IO_ERROR_PERMISSION_DENIED = 14
    IO_ERROR_CANCELLED = 19

    # The domain g_spawn_check_wait_status() uses for a child that exited
    # with a non-zero status, and whose code is that status. Upstream's
    # subprocess_error is one of these, and handle_error steals it as the
    # error it emits, so `stopped` carries this domain and the child's exit
    # status rather than a GIOError.
    SPAWN_EXIT_ERROR_QUARK = "g-spawn-exit-error"

    # The exit statuses pkexec uses, which upstream's handle_error reads back
    # off the subprocess and reports as two quite different things.
    PKEXEC_DISMISSED_STATUS = 126
    PKEXEC_UNAUTHORIZED_STATUS = 127

    # Prefix of the name claimed by the connection that collects name owners,
    # as c-sources/pcap-monitor.c names it.
    MONITOR_NAME_PREFIX = "org.freedesktop.Bustle.Monitor."

    DBUS_PATH = "/org/freedesktop/DBus"

    # Upstream's flags for the name-collecting connection: it speaks to a
    # message bus and authenticates as a client, so it gets a unique name.
    CONNECTION_FLAGS = Gio::DBusConnectionFlags::AUTHENTICATION_CLIENT |
                       Gio::DBusConnectionFlags::MESSAGE_BUS_CONNECTION

    # -1 is GDBus's own default timeout, which is what upstream passes.
    CALL_TIMEOUT = -1

    # The three bus methods this makes, and what each one replies with.
    REPLY_SIGNATURES = {
      "RequestName"  => "(u)",
      "ListNames"    => "(as)",
      "GetNameOwner" => "(s)",
    }.freeze

    READ_SIZE = 64 * 1024

    # How long #run waits for the pipe before looking at its own flags again.
    POLL_INTERVAL = 0.2

    # Upstream's await_both_errors() waits two seconds for a dbus-monitor
    # that has been asked to go away, and then emits `stopped` whether or not
    # the child ever exited — a privileged dbus-monitor cannot be signalled
    # by the unprivileged process that spawned it, so waiting for it would
    # mean never stopping.
    STOP_TIMEOUT_SECONDS = 2

    # How long #close waits for the child to be reaped. A child that has had
    # SIGTERM, a closed pipe and SIGKILL and is still there is not going to
    # be waited for: upstream does not wait for it either.
    JOIN_TIMEOUT = 0.2

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
      @pcap_error = nil
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
    #
    # The main context is iterated as well as the pipe read, because the
    # name-collecting connection of #seed_names is opened asynchronously and
    # its callback arrives on the default context — which the GUI's main loop
    # turns for us and a command-line recorder has to turn for itself.
    def run
      until @stopped
        wait_for_pipe
        pump
        GLib::MainContext.default.iteration(false)
      end
      self
    end

    # Upstream's bustle_pcap_monitor_stop(), by way of
    # cancellable_cancelled_cb(): flush whatever the subprocess has already
    # written, ask it to go away, close the read end of its stdout so that it
    # dies of EPIPE if the signal could not reach it, and arm the timeout
    # that reports `stopped` whether or not it ever exits.
    def stop
      @cancelled = true
      unless @stopped
        drain
        terminate
        close_pipe
        arm_stop_timeout
      end
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
        unless read_global_header || @stopped || @pcap_error
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
          unless @pcap_error
            link_type = unpack_word(header[20, 4])
            if [PcapLoader::LINK_TYPE_NULL, PcapLoader::LINK_TYPE_DBUS].include?(link_type)
              seed_names
            else
              fail_pcap("Incorrect link type #{link_type}")
            end
          end
        end
      end

      # Upstream dispatches dump_names_async() from start_pcap(), the moment
      # the pcap stream proves readable — which is also the moment
      # dbus-monitor is known to be connected to the bus, so everything below
      # lands in the log. Here the equivalent moment is a global header that
      # parsed and named a link type we understand.
      #
      # pcap-monitor.c says what the exercise is for in its own words: the
      # GetNameOwner replies are "just used by the UI to fill in the initial
      # owners of each well-known name". Nothing in a capture says which
      # well-known names a connection already owned when recording started —
      # NameOwnerChanged only reports changes — so without this every service
      # that was already on the bus is drawn as a bare unique name, and the
      # filter dialog lists unique names instead of service names.
      #
      # The connection is opened asynchronously, as upstream opens it on a
      # thread, because a bus with two hundred names on it is two hundred
      # round trips and neither the GUI nor the pipe can wait for them.
      def seed_names
        bus_address.then do |address|
          if address
            Gio::DBusConnection.new_for_address(
              address,
              CONNECTION_FLAGS,
              nil,
              nil,
            ) { |*results| dump_names(results.find { |result| result.is_a?(Gio::DBusConnection) }) }
          end
        end
      rescue GLib::Error
        # A bus that cannot be reached a second time costs the log its initial
        # name owners; it does not stop the recording, which is dbus-monitor's
        # job and is already under way.
        nil
      end

      # Upstream's get_connection: the address it was given, or the address of
      # the bus it was told to record.
      def bus_address
        case @target
        when SESSION_BUS then Gio::DBus.address_get_for_bus_sync(:session, nil)
        when SYSTEM_BUS then Gio::DBus.address_get_for_bus_sync(:system, nil)
        else @target.to_s
        end
      rescue GLib::Error
        nil
      end

      # Upstream's dump_names_thread_func, minus the thread: claim a name, ask
      # after every well-known name, hang up.
      def dump_names(connection)
        if connection && !@stopped
          request_monitor_name(connection)
          well_known_names(connection).each { |name| get_name_owner(connection, name) }
        end
        connection&.close_sync(nil)
      rescue GLib::Error
        nil
      end

      # Upstream owns org.freedesktop.Bustle.Monitor.<unique name> on this
      # connection so the viewer can hide the monitor's own traffic, mangling
      # ":1.42" into "_1_42" with g_strcanon — every character that is not a
      # digit becomes an underscore, because a bus name component can hold
      # neither a colon nor a dot. g_bus_own_name_on_connection() is not in
      # the Ruby bindings, and what it sends is this RequestName call, which
      # is what the viewer is reading the log for; upstream notes that merely
      # requesting the name is enough, which is as well, because on the system
      # bus the request is refused.
      def request_monitor_name(connection)
        connection.unique_name.then do |unique_name|
          if unique_name
            call(connection, "RequestName", arguments("(su)", "('#{monitor_name(unique_name)}', 0)"))
          end
        end
      end

      def monitor_name(unique_name) = "#{MONITOR_NAME_PREFIX}#{unique_name.gsub(/[^0-9]/, "_")}"

      # Unique names are skipped because a unique name owns itself, and
      # org.freedesktop.DBus because the bus is not a name the bus hands out,
      # exactly as upstream's list_all_names filters them.
      def well_known_names(connection)
        call(connection, "ListNames", nil).then do |reply|
          if reply
            reply.first.reject { |name| name.start_with?(":") || name == Types::DBUS_NAME }
          else
            []
          end
        end
      end

      # The reply is deliberately thrown away: it is the capture that wants
      # it, not us. An error is thrown away too — upstream's comment explains
      # that an owner which vanished between ListNames and here will have sent
      # a NameOwnerChanged the viewer can read instead.
      def get_name_owner(connection, name)
        call(connection, "GetNameOwner", arguments("(s)", "('#{name}',)"))
      end

      # Bus names are made of letters, digits, dots, dashes and underscores,
      # so none of them needs escaping in GVariant's text form — and the Ruby
      # bindings offer no other way to build a tuple variant.
      def arguments(signature, text) = GLib::Variant.parse(text, signature)

      def call(connection, member, parameters)
        connection.call_sync(
          Types::DBUS_NAME,
          DBUS_PATH,
          Types::DBUS_INTERFACE,
          member,
          parameters,
          GLib::VariantType.new(REPLY_SIGNATURES.fetch(member)),
          Gio::DBusCallFlags::NONE,
          CALL_TIMEOUT,
          nil,
        )
      rescue GLib::Error
        nil
      end

      def byte_order_of(header)
        case header[0, 4].unpack1("H8")
        when "d4c3b2a1" then :little
        when "a1b2c3d4" then :big
        else
          fail_pcap("Couldn't read messages from dbus-monitor: not a pcap stream")
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

      # Blocks until the pipe has something to say, or the poll interval is
      # up. Once #stop has closed the read end there is nothing to select on,
      # so the loop just turns the main context until the timeout fires.
      def wait_for_pipe
        unless @pipe.nil? || @pipe.closed?
          IO.select(
            [@pipe],
            nil,
            nil,
            POLL_INTERVAL,
          )
        end
      rescue IOError
        nil
      end

      def terminate(signal = "TERM")
        if @process&.alive?
          Process.kill(signal, @process.pid)
        end
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end

      # Upstream's cancellable_cancelled_cb pcap_close()es the stream it was
      # reading, which closes the read end of dbus-monitor's stdout; the next
      # frame dbus-monitor writes then kills it. Here it also ends the read
      # loop: read_nonblock on a closed pipe raises, which #drain reads as end
      # of stream and reports as the cancellation it is.
      def close_pipe
        unless @pipe.nil? || @pipe.closed?
          @pipe.close
        end
      rescue IOError
        nil
      end

      # Upstream's await_both_errors(): after two seconds, emit `stopped`
      # with whatever is known, exited child or not. The force-exit upstream
      # does at cancellation time is deferred to here so that a dbus-monitor
      # which was going to notice the closed pipe gets the chance; one that
      # has not noticed by now never will, and is not left behind writing
      # into a pipe nobody holds.
      def arm_stop_timeout
        unless @stopped
          GLib::Timeout.add_seconds(STOP_TIMEOUT_SECONDS) do
            terminate("KILL")
            finish
            false
          end
        end
      end

      # Upstream's read_one() hands a bad pcap stream (wrong magic, an
      # unrecognised link type) back as self->pcap_error rather than tearing
      # the recorder down on the spot, because handle_error() wants the
      # chance to weigh it against whatever the subprocess itself reports —
      # see #report_exit. So this does what #stop does to make the
      # subprocess go away — terminate it, close the read end so a laggard
      # dies of EPIPE, arm the same fallback timeout — without declaring the
      # stop itself; that is left for the EOF this provokes to report
      # through the normal #finish path.
      def fail_pcap(message)
        unless @pcap_error
          @pcap_error = message
          terminate
          close_pipe
          arm_stop_timeout
        end
      end

      # End of the pipe: the recording is over. A stop the user asked for is
      # reported as cancelled, which is the one error the recorder swallows.
      def finish
        if @cancelled
          stop_with(IO_ERROR_CANCELLED, "")
        else
          pass_on_diagnostics
          report_exit(wait_status)
        end
      end

      # Upstream's handle_error reads the subprocess's exit status and reports
      # three of them as something other than a failure. 126 and 127 are
      # pkexec's, so they only mean this on the system bus: the user closed
      # the authorisation dialog — which the recorder then swallows, exactly
      # as it swallows a stop the user asked for — or polkit refused. A clean
      # exit is the bus itself going away, which upstream also calls
      # cancellation, with a comment about monitoring a test suite or a
      # session you then log out of.
      #
      # Anything else is the subprocess's own error, which upstream emits
      # unchanged: G_SPAWN_EXIT_ERROR and the exit status. A child killed by a
      # signal has no exit status to report, so it keeps the GIOError domain
      # — upstream's would carry G_SPAWN_ERROR, whose numbering the Ruby
      # bindings do not expose.
      #
      # Upstream's handle_error() weighs a pcap_error against a
      # subprocess_error only after the pkexec and clean-exit cases above
      # have had their say — those two are reported unconditionally — and
      # only when it has no more specific subprocess_error of its own: "If no
      # pkexec errors, prefer potentially more informative errors from
      # libpcap, including the wonderful snaplen bug." A libpcap failure
      # (#fail_pcap) outranks a bare non-zero exit status for the same
      # reason it does upstream — dbus-monitor exiting badly is usually just
      # it noticing the pipe it was writing a corrupt or truncated stream
      # into had gone away, and the pcap-level error says what actually went
      # wrong.
      def report_exit(status)
        if @target == SYSTEM_BUS && status&.exitstatus == PKEXEC_DISMISSED_STATUS
          stop_with(IO_ERROR_CANCELLED, "User dismissed polkit authorization dialog")
        elsif @target == SYSTEM_BUS && status&.exitstatus == PKEXEC_UNAUTHORIZED_STATUS
          stop_with(IO_ERROR_PERMISSION_DENIED, "Not authorized to monitor system bus")
        elsif status&.exitstatus&.zero?
          stop_with(IO_ERROR_CANCELLED, "dbus-monitor exited cleanly")
        elsif @pcap_error
          stop_with(IO_ERROR_FAILED, @pcap_error)
        elsif status&.exitstatus
          stop_with(status.exitstatus, prefixed(spawn_message(status)), domain: SPAWN_EXIT_ERROR_QUARK)
        else
          stop_with(IO_ERROR_FAILED, prefixed(spawn_message(status)))
        end
      end

      def wait_status
        @process&.value
      rescue IOError
        nil
      end

      # GLib's own wording for a child that exited or was killed, which is
      # what upstream's G_SPAWN_EXIT_ERROR message carries.
      def spawn_message(status)
        case
        when status.nil? then "EOF when reading from dbus-monitor"
        when status.signaled? then "Child process killed by signal #{status.termsig}"
        else "Child process exited with code #{status.exitstatus}"
        end
      end

      # Upstream prefixes the subprocess's complaint while the monitor is
      # still starting up, which here means no pcap header ever arrived.
      def prefixed(message)
        if @byte_order
          message
        else
          "Failed to start dbus-monitor: #{message}"
        end
      end

      # dbus-monitor's stderr is inherited by upstream's monitor and so lands
      # on the terminal; this one captures it to keep it out of the pcap
      # stream, so it is written back out where upstream's would have gone.
      def pass_on_diagnostics
        diagnostics.then do |text|
          unless text.empty?
            $stderr.write("#{text}\n")
          end
        end
      end

      def diagnostics
        @errors.read.to_s.strip
      rescue IOError
        ""
      end

      # The domain defaults to GIOError because that is the domain upstream
      # builds its own errors in — cancellation, a dismissed polkit dialog, a
      # refused one, an unreadable stream. The one error it does not build but
      # steals is the subprocess's, and that one arrives with
      # SPAWN_EXIT_ERROR_QUARK and the child's exit status.
      def stop_with(code, message, domain: IO_ERROR_QUARK)
        unless @stopped
          @stopped = true
          close
          emit(
            STOPPED,
            domain,
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
        @process&.join(JOIN_TIMEOUT)
      rescue IOError
        nil
      end

      def emit(name, *arguments)
        @handlers.fetch(name).each { |handler| handler.call(*arguments) }
      end
  end
end
