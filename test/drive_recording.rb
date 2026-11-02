# frozen_string_literal: true

# Records the session bus through the GUI and checks that what came back is a
# diagram. This is the path upstream's Monitor.hs and pcap-monitor.c drive:
# dbus-monitor writes pcap, the monitor reads it, the recorder renders it, and
# a second connection to the same bus seeds the well-known names so services
# are drawn under their own names.
#
# It needs a session bus of its own, so run it as
#
#   nix develop --command dbus-run-session -- xvfb-run -a ruby test/drive_recording.rb
#
# This is where component 21 of .reports/component-inventory.md — the live bus
# monitor — is exercised and claimed. test/drive_all.rb runs this script and
# test/drive_bustle.rb and sums what the two of them covered.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "tmpdir"

require_relative "gtk_driver"

require "bustle/application"
require "bustle/pcap_loader"
require "bustle/types"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir

MONITOR_NAME_PREFIX = Bustle::Monitor::MONITOR_NAME_PREFIX

application = Bustle::Application.new(app_id: "org.rubygtkproject.Bustle.DriveRecording")
log_path = nil
# The window drops its recorder once the recording has finished, so it is
# captured while the recording is still under way.
recorder = nil

GtkDriver.drive(application, shots: ENV.fetch("BUSTLE_SHOTS", File.join(Dir.tmpdir, "bustle-shots")), interval: 3000) do |d, app|
  d.window { app.windows.first.window }

  d.step("start recording the session bus") do
    app.windows.first.window.activate_action("record-session", nil)
  end

  d.step("make some traffic to record") do
    system("dbus-send --session --print-reply --dest=org.freedesktop.Nonexistent /x org.example.Iface.Ping >/dev/null 2>&1")
    system("dbus-send --session --type=signal / org.example.Iface.Pinged >/dev/null 2>&1")
  end

  d.step("the recording is under way") do
    window = app.windows.first
    recorder = window.instance_variable_get(:@recorder)
    log_path = recorder.monitor.filename
    d.check("the log is being written") { File.size?(log_path).to_i.positive? }
    d.check("the header says which bus is being recorded") do
      window.header_bar.title_label.label == "Recording session bus&#8230;"
    end
    d.check("Stop replaced Record and Open") do
      window.header_bar.stop_button.visible? && !window.header_bar.record_button.visible?
    end
    d.check("starting a recording cleared any earlier error") do
      !window.error_bar.container.visible?
    end
    d.shot("r1-recording")
  end

  d.step("stop") { app.windows.first.header_bar.stop_button.activate }

  d.step("the diagram shows what was recorded") do
    d.check("shapes were drawn") { !app.windows.first.canvas.shapes.empty? }
    d.shot("r2-stopped")
  end

  d.step("stopping a recording leaves nothing running") do
    d.check("the window let go of its recorder, so the recording finished") do
      app.windows.first.instance_variable_get(:@recorder).nil?
    end
    d.check("the monitor reported itself stopped") { recorder.monitor.stopped? }
    d.check("and dbus-monitor is gone") { !recorder.monitor.instance_variable_get(:@process).alive? }
  end

  d.step("the log names the monitor's own connection") do
    _warnings, log = Bustle::PcapLoader.read_pcap(log_path)
    names = log.map(&:event).grep(Bustle::Types::NameChanged).map { |event| event.changed_name.to_s }
    d.check("the monitor claimed a name of its own") do
      names.any? { |name| name.start_with?(MONITOR_NAME_PREFIX) }
    end
  end

  d.step("this script covered the live bus monitor") do
    # Component 21 of .reports/component-inventory.md is this script's whole
    # subject: spawned, read, rendered and stopped above. test/drive_all.rb
    # reads this line.
    puts "DRIVE COVERED 21"
  end
end
