# frozen_string_literal: true

# The spec task, for the environments where nothing else defines one.
#
# The templated Rakefile advertises `rake spec` and `rake test`, but both come
# from kettle-dev, which prints
#
#   NOTE: kettle-dev isn't installed, or is disabled for 3.4.9 in the current
#   environment
#
# in this dev shell and then defines neither. So the declared target did not
# exist and the suite could only be run by hand. This defines it, in the same
# shape spec/spec_helper.rb already degrades in: RSpec directly, no kettle.
#
# Two of the specs load gtk4, which needs a display even to be required, so a
# run with no DISPLAY re-execs itself under the dev shell's xvfb-run — the
# same thing the shell's banner tells a human to type.

SPEC_PATTERN = "spec"

XVFB = "xvfb-run"

def spec_display? = !ENV["DISPLAY"].to_s.empty?

def spec_xvfb
  ENV["PATH"].to_s.split(File::PATH_SEPARATOR).find { |dir| File.executable?(File.join(dir, XVFB)) }
end

namespace :spec do
  desc "Run the specs in this process, with a display already available"
  task :direct do
    require "rspec/core"
    RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", SPEC_PATTERN]).then do |status|
      unless status.zero?
        raise "specs failed (exit #{status})"
      end
    end
  end
end

unless Rake::Task.task_defined?("spec")
  desc "Run RSpec code examples"
  task :spec do
    if spec_display? || spec_xvfb.nil?
      Rake::Task["spec:direct"].invoke
    else
      sh(
        File.join(spec_xvfb, XVFB),
        "-a",
        RbConfig.ruby,
        "-S",
        $PROGRAM_NAME,
        "spec:direct",
      )
    end
  end
end

unless Rake::Task.task_defined?("test")
  desc "Run tests"
  task test: :spec
end

task default: :spec
