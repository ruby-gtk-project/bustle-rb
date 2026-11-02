# frozen_string_literal: true

require_relative "loader"
require_relative "stats"
require_relative "translation"
require_relative "types"

module Bustle
  # The batch modes: --count, --time and --dot.
  #
  # Ported from upstream's Bustle/Noninteractive.hs. Each one loads a log,
  # runs one analysis over it and prints the result a line at a time, so the
  # output can be piped into sort, grep or dot without a display. A log that
  # will not load is a fatal error with the same message the window's error
  # bar would have shown.
  module Noninteractive
    class << self
      # Message frequencies, busiest first.
      def run_count(path, output: $stdout)
        process(path, output) do |log|
          Stats.frequencies(log).map do |info|
            format(
              " %<count>4d %<kind>6s %<interface>s.%<member>s",
              count:     info.frequency,
              kind:      type_name(info.type),
              interface: format_interface(info.interface),
              member:    info.member,
            )
          end
        end
      end

      # Method call durations, slowest total first.
      def run_time(path, output: $stdout)
        process(path, output) do |log|
          Stats.method_times(log).map do |info|
            format(
              " %<total>9.4f %<calls>3d %<mean>9.4f %<interface>s.%<member>s",
              total:     info.total_time,
              calls:     info.call_frequency,
              mean:      info.mean_call_time,
              interface: format_interface(info.interface),
              member:    info.method_name,
            )
          end
        end
      end

      # Who calls whom, as a graph for dot(1).
      def run_dot(path, output: $stdout)
        process(path, output) { |log| digraph(log) }
      end

      private

        def process(path, output, &analyze)
          warnings, log = Loader.read_log(path)
          warnings.each { |warning| $stderr.puts(warning) }
          analyze.call(log).each { |line| output.puts(line) }
          true
        rescue Loader::LoadError => e
          $stderr.puts(format(Bustle._("Couldn't parse '%s': %s"), e.path, e.message))
          false
        end

        def digraph(log)
          ["digraph bustle {", *edges(log), "}"]
        end

        def edges(log)
          log.filter_map { |detailed| call_pair(detailed.event) }
             .uniq
             .map { |sender, destination| %(  "#{sender}" -> "#{destination}";) }
        end

        def call_pair(event)
          case event
          when Types::MethodCall then [event.sender.to_s, event.destination.to_s]
          end
        end

        def type_name(type)
          case type
          when Stats::METHOD then "method"
          when Stats::SIGNAL then "signal"
          end
        end

        def format_interface(interface)
          if interface
            interface.to_s
          else
            Bustle._("(no interface)")
          end
        end
    end
  end
end
