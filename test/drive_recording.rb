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
    log_path = app.windows.first.instance_variable_get(:@recorder).monitor.filename
    d.check("the log is being written") { File.size?(log_path).to_i.positive? }
    d.shot("r1-recording")
  end

  d.step("stop") { app.windows.first.header_bar.stop_button.activate }

  d.step("the diagram shows what was recorded") do
    d.check("shapes were drawn") { !app.windows.first.canvas.shapes.empty? }
    d.shot("r2-stopped")
  end

  d.step("the log names the monitor's own connection") do
    _warnings, log = Bustle::PcapLoader.read_pcap(log_path)
    names = log.map(&:event).grep(Bustle::Types::NameChanged).map { |event| event.changed_name.to_s }
    d.check("the monitor claimed a name of its own") do
      names.any? { |name| name.start_with?(MONITOR_NAME_PREFIX) }
    end
  end
end
