# frozen_string_literal: true

# The coverage gate: runs both drive scripts, sums what they covered, and
# fails unless every component in .reports/component-inventory.md was
# exercised by one of them.
#
#   nix develop --command ruby test/drive_all.rb
#
# This exists because the claim "22 of 22 components exercised" was being made
# by test/drive_bustle.rb alone, which cannot run component 21 — the live bus
# monitor needs a session bus of its own — and cannot know whether the script
# that does ran at all. So each script prints the components it covered and
# this one adds them up, over both runs' checks.

require "English"

ROOT = File.expand_path("..", __dir__)

COMPONENTS = 22

# test/drive_recording.rb needs a session bus; xvfb-run gives both scripts the
# display GTK4 wants even on a machine with none.
SCRIPTS = [
  ["xvfb-run", "-a", "ruby", File.join(ROOT, "test/drive_bustle.rb")],
  ["dbus-run-session", "--", "xvfb-run", "-a", "ruby", File.join(ROOT, "test/drive_recording.rb")],
].freeze

COVERED_LINE = /^DRIVE COVERED ([\d,]*)$/

CHECKS_LINE = /^(\d+) of (\d+) checks passed$/

# One script's run: what it covered, how its checks went, how it exited.
Run = Struct.new(
  :command,
  :status,
  :covered,
  :passed,
  :checks,
)

# The output is echoed as it is read, so a failing run is diagnosable from
# this script's own output and not only from the script's.
def capture(command)
  IO.popen(command, err: [:child, :out]) { |pipe| pipe.read.tap { |output| print(output) } }
    .then { |output| summarise(command, output, $CHILD_STATUS) }
end

def summarise(command, output, status)
  output.scan(CHECKS_LINE).flatten.then do |counts|
    Run.new(
      command,
      status.exitstatus,
      output.scan(COVERED_LINE).flatten.flat_map { |list| list.split(",").map(&:to_i) }.uniq,
      counts.first.to_i,
      counts.last.to_i,
    )
  end
end

def report(run)
  puts "#{run.command.join(" ")}: exit #{run.status}, " \
       "#{run.passed} of #{run.checks} checks passed, " \
       "components #{run.covered.sort.join(", ")}"
end

SCRIPTS.map { |command| puts("=== #{command.join(" ")}").then { capture(command) } }.then do |runs|
  puts
  runs.each { |run| report(run) }

  [
    runs.sum(&:checks),
    runs.sum(&:passed),
    runs.flat_map(&:covered).uniq.sort,
  ].then do |checks, passed, covered|
    puts
    puts "#{passed} of #{checks} checks passed over #{runs.length} drive scripts"
    puts "components covered: #{covered.length} of #{COMPONENTS}: #{covered.join(", ")}"

    (covered == (1..COMPONENTS).to_a && runs.map(&:status).all?(&:zero?) && passed == checks)
      .then do |ok|
      puts(ok ? "DRIVE ALL OK" : "DRIVE ALL FAILED")
      exit(ok ? 0 : 1)
    end
  end
end
