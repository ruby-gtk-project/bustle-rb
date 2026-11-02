# frozen_string_literal: true

require_relative "types"

module Bustle
  # The three tables behind the statistics sidebar.
  #
  # Ported from upstream's Bustle/Stats.hs: how often each member appears, how
  # long each method call took to return, and how big the messages were. All
  # three fold the log into a table keyed by (kind, interface, member) and then
  # sort the result descending, so the busiest, slowest and fattest rows come
  # first.
  #
  # Messages whose interface is absent sort before the ones that have it,
  # matching upstream's ordering of Maybe InterfaceName.
  module Stats
    METHOD = :method
    SIGNAL = :signal

    SIZE_CALL = :call
    SIZE_RETURN = :return
    SIZE_ERROR = :error
    SIZE_SIGNAL = :signal

    TALLY_RANKS = {METHOD => 0, SIGNAL => 1}.freeze
    SIZE_RANKS = {SIZE_CALL => 0, SIZE_RETURN => 1, SIZE_ERROR => 2, SIZE_SIGNAL => 3}.freeze

    FrequencyInfo = Data.define(
      :frequency,
      :type,
      :interface,
      :member,
    )
    TimeInfo = Data.define(
      :interface,
      :method_name,
      :total_time,
      :call_frequency,
      :mean_call_time,
    )
    SizeInfo = Data.define(
      :mean_size,
      :max_size,
      :min_size,
      :type,
      :interface,
      :name,
    )

    class << self
      # How many times each method was called and each signal emitted.
      def frequencies(log)
        tally = {}
        log.each do |detailed|
          key = frequency_key(detailed)
          if key
            tally[key] = tally.fetch(key, 0) + 1
          end
        end
        tally.map { |(type, interface, member), count| FrequencyInfo.new(frequency: count, type:, interface:, member:) }
             .sort_by { |info| [-info.frequency, TALLY_RANKS.fetch(info.type), *name_key(info.interface), info.member] }
      end

      # Total, count and mean call-to-return time per method, in milliseconds.
      # Calls whose reply is missing from the log contribute nothing, because
      # the loader never paired them up.
      def method_times(log)
        durations = {}
        Types.partition_detaileds(log).last.each do |detailed|
          pair = method_return_duration(detailed)
          if pair
            key, duration = pair
            (durations[key] ||= []) << duration
          end
        end
        durations.map { |(interface, method_name), times| summarize_times(interface, method_name, times) }
                 .sort_by { |info| [-info.total_time, *name_key(info.interface), info.method_name] }
      end

      # Mean, largest and smallest marshalled size per message kind and member.
      # A return or an error is filed under the member of the call it answers,
      # which is the only name it has.
      def message_sizes(log)
        sizes = {}
        Types.partition_detaileds(log).last.each do |detailed|
          key = size_key(detailed)
          if key
            (sizes[key] ||= []) << detailed.message_size
          end
        end
        sizes.map { |(type, interface, name), observed| summarize_sizes(
          type,
          interface,
          name,
          observed,
        ) }
             .sort_by do |info|
               [-info.mean_size, -info.max_size, -info.min_size,
                SIZE_RANKS.fetch(info.type), *name_key(info.interface), info.name
]
             end
      end

      private

        def frequency_key(detailed)
          case detailed.event
          when Types::MethodCall
            [METHOD, detailed.event.member.interface, detailed.event.member.member_name]
          when Types::Signal
            [SIGNAL, detailed.event.member.interface, detailed.event.member.member_name]
          end
        end

        def method_return_duration(detailed)
          case detailed.event
          when Types::MethodReturn
            detailed.event.in_reply_to.then do |call|
              if call && call.event.is_a?(Types::MethodCall)
                [[call.event.member.interface, call.event.member.member_name],
                 detailed.timestamp - call.timestamp
]
              end
            end
          end
        end

        def size_key(detailed)
          case detailed.event
          when Types::MethodCall
            [SIZE_CALL, detailed.event.member.interface, detailed.event.member.member_name]
          when Types::Signal
            [SIZE_SIGNAL, detailed.event.member.interface, detailed.event.member.member_name]
          when Types::MethodReturn
            call_details(detailed.event)&.unshift(SIZE_RETURN)
          when Types::ErrorReturn
            call_details(detailed.event)&.unshift(SIZE_ERROR)
          end
        end

        def call_details(message)
          message.in_reply_to.then do |call|
            if call
              [call.event.member.interface, call.event.member.member_name]
            end
          end
        end

        def summarize_times(interface, method_name, times)
          TimeInfo.new(
            interface:,
            method_name:,
            total_time: times.sum / 1000.0,
            call_frequency: times.length,
            mean_call_time: (times.sum.to_f / times.length) / 1000.0,
          )
        end

        def summarize_sizes(type, interface, name, observed)
          SizeInfo.new(
            mean_size: (observed.sum.to_f / observed.length).ceil,
            max_size:  observed.max,
            min_size:  observed.min,
            type:,
            interface:,
            name:,
          )
        end

        # Sorts the messages without an interface ahead of the ones with one,
        # and keeps a nil out of the comparison, which Ruby would refuse.
        def name_key(interface)
          if interface
            [1, interface.to_s]
          else
            [0, ""]
          end
        end
    end
  end
end
