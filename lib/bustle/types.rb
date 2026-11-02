# frozen_string_literal: true

module Bustle
  # The model: D-Bus names, members, messages, bus-name-owner changes, and the
  # timestamped envelope every one of them arrives in.
  #
  # Ported from upstream's Bustle/Types.hs. Upstream wraps bus names in
  # newtypes (UniqueName, OtherName, TaggedBusName) so the renderer cannot
  # confuse ":1.42" with "org.example.Thing"; here one BusName value object
  # carries the distinction in its `kind`, which it works out from the leading
  # colon exactly as upstream's Loader does.
  #
  # Every type is a Data class: the renderer keys hashes and sets on messages
  # and names, so structural equality and hashing are load-bearing.
  module Types
    DBUS_NAME = "org.freedesktop.DBus"
    DBUS_INTERFACE = "org.freedesktop.DBus"

    # A bus name, tagged as a unique name (":1.42") or a well-known one.
    BusName = Data.define(:name, :kind) do
      def unique? = kind == :unique

      def other? = kind == :other

      def to_s = name
    end

    # A member of an interface on an object: the triple a call or signal names.
    # `interface` is nil for the (legal, rare) messages that omit it.
    Member = Data.define(:path, :interface, :member_name)

    MethodCall = Data.define(
      :serial,
      :sender,
      :destination,
      :member,
    )
    MethodReturn = Data.define(:in_reply_to, :sender, :destination)
    ErrorReturn = Data.define(:in_reply_to, :sender, :destination)
    Signal = Data.define(:sender, :signal_destination, :member)

    Connected = Data.define(:actor)
    Disconnected = Data.define(:actor)
    NameChanged = Data.define(:changed_name, :change)

    Claimed = Data.define(:new_owner)
    Stolen = Data.define(:old_owner, :new_owner)
    Released = Data.define(:old_owner)

    MESSAGE_CLASSES = [MethodCall, MethodReturn, ErrorReturn, Signal].freeze
    NOC_CLASSES = [Connected, Disconnected, NameChanged].freeze

    # A D-Bus value with the signature it was marshalled under, so the details
    # pane can print "@as [...]" without re-deriving the type from the value.
    Variant = Data.define(:signature, :value)

    # One event, as logged: the capture timestamp in microseconds, the event
    # itself, the size of the marshalled message in bytes, and its arguments.
    Detailed = Data.define(
      :timestamp,
      :event,
      :message_size,
      :body,
    ) do
      def message? = MESSAGE_CLASSES.include?(event.class)

      def noc? = NOC_CLASSES.include?(event.class)

      # Upstream's Ord instance compares on (timestamp, event); the renderer
      # relies on the timestamp half when it interleaves two buses' logs.
      def <=>(other) = timestamp <=> other.timestamp
    end

    class << self
      def unique_name(name) = BusName.new(name:, kind: :unique)

      def other_name(name) = BusName.new(name:, kind: :other)

      # The bus itself, as it appears in the sender/destination of the
      # messages the loader filters out.
      def dbus_bus_name = other_name(DBUS_NAME)

      # A unique name is the one beginning with a colon; everything else is
      # well-known. Upstream's Loader.Pcap makes the same test.
      def tagged_bus_name(name)
        if name.to_s.start_with?(":")
          unique_name(name.to_s)
        else
          other_name(name.to_s)
        end
      end

      # Logs that never saw a NameOwnerChanged for a name still need a unique
      # name to hang a column off; upstream invents ":fake.N" names for them.
      def fake_unique_name(suffix) = unique_name(":fake.#{suffix}")

      def us_to_ms(microseconds) = microseconds / 1000

      # Splits a log into its NameOwnerChanged events and its messages, which
      # is how the statistics and the renderer both start.
      def partition_detaileds(log)
        log.partition(&:noc?)
      end

      # The names a message involves, which is what the service filter tests
      # when it decides whether to hide the message.
      def mentioned_names(message)
        case message
        when Signal then [message.sender, message.signal_destination].compact
        else [message.sender, message.destination].compact
        end
      end
    end
  end
end
