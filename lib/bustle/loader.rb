# frozen_string_literal: true

require_relative "pcap_loader"
require_relative "translation"
require_relative "types"

module Bustle
  # Loads a log off disk and throws away the messages nobody wants to see.
  #
  # Ported from upstream's Bustle/Loader.hs. The filtering matters: a log
  # recorded with dbus-monitor is full of traffic to and from the bus daemon
  # itself (AddMatch, Hello, GetNameOwner, ListNames) which would otherwise
  # dominate the diagram. Signals *from* the bus are dropped too, except that
  # the loader has already turned NameOwnerChanged into a model event, so the
  # columns still appear and disappear at the right moments.
  module Loader
    # The log could not be read at all: not a pcap file, wrong link type, or
    # unreadable.
    class LoadError < StandardError
      attr_reader :path

      def initialize(path, message)
        @path = path
        super(message)
      end
    end

    class << self
      # Returns [warnings, log] for one file.
      def read_log(path)
        warnings, log = PcapLoader.read_pcap(path)
        [warnings, log.select { |detailed| relevant?(detailed.event) }]
      rescue PcapLoader::Error, SystemCallError, IOError => e
        raise LoadError.new(path, e.message)
      end

      # Upstream shares this with the live recorder, which filters each message
      # as it arrives rather than after the fact.
      def relevant?(event)
        case event
        when Types::Signal then event.sender != Types.dbus_bus_name
        when Types::MethodCall, Types::MethodReturn, Types::ErrorReturn
          event.sender != Types.dbus_bus_name && event.destination != Types.dbus_bus_name
        else true
        end
      end
    end
  end
end
