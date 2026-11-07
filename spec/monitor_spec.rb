# frozen_string_literal: true

require "shellwords"
require "tmpdir"

require "bustle/monitor"
require "bustle/pcap_loader"

# Component 21 (lib/bustle/monitor.rb) was, before this file, exercised only
# by test/drive_recording.rb's narrow pass over a real recording and by a
# 3-branch case statement in drive_bustle.rb — neither of which touches the
# pcap frame parser's byte math, the global-header dispatch, the
# exit-status-to-error mapping, or the precedence between a libpcap failure
# and a bare subprocess exit that upstream's handle_error() applies. This
# drives those paths directly, without a real dbus-monitor or bus.
#
# A subclass stands in for the real subprocess argv/seeding so each piece can
# be driven in isolation: #seed_names talks to a live bus, which these specs
# have none of, and the real #argv wants `dbus-monitor` on PATH (and
# `pkexec`/`flatpak-spawn` besides) rather than whatever a test wants to run.
class UnseededMonitor < Bustle::Monitor
  def seed_names
    nil
  end
end

class StubbedProcessMonitor < UnseededMonitor
  attr_writer :stub_argv

  def argv
    @stub_argv
  end
end

# A header-dispatch test never started a real subprocess or pipe, so there is
# nothing for #fail_pcap's own terminate/close_pipe/stop-timeout dance to act
# on; stubbing it out keeps those tests from leaving a stray GLib timeout
# armed against an object the spec is done with.
class UnsupervisedMonitor < UnseededMonitor
  def fail_pcap(message)
    @pcap_error ||= message
  end
end

RSpec.describe Bustle::Monitor do
  def little_endian_global_header(link_type)
    [0xa1b2c3d4, 2, 4, 0, 0, 65535, link_type].pack("VvvVVVV")
  end

  def big_endian_global_header(link_type)
    [0xa1b2c3d4, 2, 4, 0, 0, 65535, link_type].pack("NnnNNNN")
  end

  def little_endian_frame(seconds, microseconds, blob)
    [seconds, microseconds, blob.bytesize, blob.bytesize].pack("VVVV") + blob
  end

  describe "the pcap frame parser" do
    it "emits message-logged for one complete frame" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))
      monitor.instance_variable_set(:@byte_order, :little)
      logged = []
      monitor.signal_connect(Bustle::Monitor::MESSAGE_LOGGED) { |ts, blob| logged << [ts, blob] }

      monitor.send(:consume, little_endian_frame(1, 500_000, "hello"))

      expect(logged).to eq([[1_500_000, "hello"]])
    end

    it "emits one message per frame, in order, from a single chunk" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))
      monitor.instance_variable_set(:@byte_order, :little)
      logged = []
      monitor.signal_connect(Bustle::Monitor::MESSAGE_LOGGED) { |ts, blob| logged << [ts, blob] }

      monitor.send(:consume, little_endian_frame(0, 1, "first") + little_endian_frame(0, 2, "second"))

      expect(logged).to eq([[1, "first"], [2, "second"]])
    end

    it "waits for the rest of a frame split across chunks rather than misreading it" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))
      monitor.instance_variable_set(:@byte_order, :little)
      logged = []
      monitor.signal_connect(Bustle::Monitor::MESSAGE_LOGGED) { |ts, blob| logged << [ts, blob] }

      whole = little_endian_frame(0, 42, "split across two reads")
      monitor.send(:consume, whole[0...10])
      expect(logged).to be_empty

      monitor.send(:consume, whole[10..])
      expect(logged).to eq([[42, "split across two reads"]])
    end
  end

  describe "the global pcap header" do
    it "accepts a little-endian header with the D-Bus link type and starts reading frames" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))

      monitor.send(:consume, little_endian_global_header(Bustle::PcapLoader::LINK_TYPE_DBUS))

      expect(monitor.instance_variable_get(:@byte_order)).to eq(:little)
      expect(monitor.instance_variable_get(:@pcap_error)).to be_nil
    end

    it "accepts a big-endian header" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))

      monitor.send(:consume, big_endian_global_header(Bustle::PcapLoader::LINK_TYPE_DBUS))

      expect(monitor.instance_variable_get(:@byte_order)).to eq(:big)
      expect(monitor.instance_variable_get(:@pcap_error)).to be_nil
    end

    it "fails the recording on an unrecognised magic number, without raising" do
      monitor = UnsupervisedMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))

      monitor.send(:consume, "\x00" * Bustle::PcapLoader::GLOBAL_HEADER_SIZE)

      expect(monitor.instance_variable_get(:@pcap_error)).to match(/not a pcap stream/)
    end

    it "fails the recording on a link type that is neither DLT_NULL nor DLT_DBUS" do
      monitor = UnsupervisedMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@output, File.open(File::NULL, "wb"))

      monitor.send(:consume, little_endian_global_header(9999))

      expect(monitor.instance_variable_get(:@pcap_error)).to eq("Incorrect link type 9999")
    end
  end

  describe "exit-status mapping, and the precedence a libpcap failure takes over it" do
    def status_for(code)
      Process.spawn("sh", "-c", "exit #{code}").then do |pid|
        _pid, status = Process.wait2(pid)
        status
      end
    end

    it "reports a dismissed polkit dialog as cancelled, on the system bus only" do
      monitor = UnseededMonitor.new(target: Bustle::Monitor::SYSTEM_BUS, filename: File.join(Dir.mktmpdir, "log.pcap"))
      stopped = []
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.send(:report_exit, status_for(126))

      expect(stopped).to eq([["g-io-error-quark", Bustle::Monitor::IO_ERROR_CANCELLED, "User dismissed polkit authorization dialog"]])
    end

    it "reports an unauthorized system-bus attempt as permission denied" do
      monitor = UnseededMonitor.new(target: Bustle::Monitor::SYSTEM_BUS, filename: File.join(Dir.mktmpdir, "log.pcap"))
      stopped = []
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.send(:report_exit, status_for(127))

      expect(stopped).to eq([["g-io-error-quark", Bustle::Monitor::IO_ERROR_PERMISSION_DENIED, "Not authorized to monitor system bus"]])
    end

    it "reports a clean exit as cancellation, even with a pending pcap error" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@pcap_error, "Incorrect link type 9999")
      stopped = []
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.send(:report_exit, status_for(0))

      expect(stopped).to eq([["g-io-error-quark", Bustle::Monitor::IO_ERROR_CANCELLED, "dbus-monitor exited cleanly"]])
    end

    it "reports a bare non-zero exit as the subprocess's own error when there is no pcap error" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      stopped = []
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.send(:report_exit, status_for(13))

      expect(stopped).to eq([["g-spawn-exit-error", 13, "Failed to start dbus-monitor: Child process exited with code 13"]])
    end

    it "prefers a libpcap failure over a bare non-zero exit when both are present (G12)" do
      monitor = UnseededMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.instance_variable_set(:@pcap_error, "Incorrect link type 9999")
      stopped = []
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.send(:report_exit, status_for(13))

      expect(stopped).to eq([["g-io-error-quark", Bustle::Monitor::IO_ERROR_FAILED, "Incorrect link type 9999"]])
    end
  end

  describe "subprocess supervision" do
    it "runs the stubbed subprocess to completion and maps its exit code" do
      log_path = File.join(Dir.mktmpdir, "log.pcap")
      header = little_endian_global_header(Bustle::PcapLoader::LINK_TYPE_DBUS)
      frame = little_endian_frame(0, 1, "hi")
      # The pcap bytes go through a file rather than straight into argv
      # because the global header is full of zero words, and an argv cannot
      # carry a NUL byte.
      stream_path = File.join(Dir.mktmpdir, "stream.pcap")
      File.binwrite(stream_path, header + frame)
      monitor = StubbedProcessMonitor.new(target: :session, filename: log_path)
      monitor.stub_argv = ["sh", "-c", "cat #{Shellwords.escape(stream_path)}; exit 5"]
      logged = []
      stopped = []
      monitor.signal_connect(Bustle::Monitor::MESSAGE_LOGGED) { |ts, blob| logged << [ts, blob] }
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.start
      monitor.run

      expect(logged).to eq([[1, "hi"]])
      expect(stopped).to eq([["g-spawn-exit-error", 5, "Child process exited with code 5"]])
      expect(monitor).to be_stopped
    end

    it "terminates a subprocess that outlives the recording and reports a user stop" do
      monitor = StubbedProcessMonitor.new(target: :session, filename: File.join(Dir.mktmpdir, "log.pcap"))
      monitor.stub_argv = ["sh", "-c", "trap '' TERM; sleep 30"]
      stopped = []
      monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, message| stopped << [domain, code, message] }

      monitor.start
      pid = monitor.instance_variable_get(:@process).pid
      monitor.stop
      # #stop's own two-second timeout is the backstop if the child ignores
      # SIGTERM (as this one does); give it a moment to fire, then force the
      # child out of the test run regardless of what the monitor did.
      deadline = Time.now + 4
      until monitor.stopped? || Time.now > deadline
        GLib::MainContext.default.iteration(true)
      end

      expect(monitor).to be_stopped
      expect(stopped).to eq([["g-io-error-quark", Bustle::Monitor::IO_ERROR_CANCELLED, ""]])
    ensure
      begin
        Process.kill("KILL", pid)
        Process.wait(pid)
      rescue Errno::ESRCH, Errno::ECHILD
        nil
      end
    end
  end
end
