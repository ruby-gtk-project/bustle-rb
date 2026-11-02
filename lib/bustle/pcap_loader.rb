# frozen_string_literal: true

require_relative "types"
require_relative "translation"
require_relative "variant_formatter"

module Bustle
  # Reads a pcap file full of D-Bus traffic into the model.
  #
  # Ported from upstream's Bustle/Loader/Pcap.hs, which leans on libpcap and
  # the Haskell `dbus` package. Neither has a Ruby equivalent worth a
  # dependency, so this file does both jobs: a pcap reader (classic
  # tcpdump-format files, either byte order, link type DLT_NULL for very old
  # logs or DLT_DBUS=231 for everything since) and a D-Bus unmarshaller for
  # the messages in the packets.
  #
  # The interesting part is the same as upstream's: a method return carries
  # nothing but a reply serial, so the loader keeps a table of calls it has
  # seen and hands each reply the call it answers. A reply to GetNameOwner is
  # turned into a name-owner-changed event, because a log that starts mid-flight
  # has no other way of learning who owns a well-known name.
  module PcapLoader
    LINK_TYPE_NULL = 0
    LINK_TYPE_DBUS = 231

    GLOBAL_HEADER_SIZE = 24
    PACKET_HEADER_SIZE = 16

    MESSAGE_TYPE_METHOD_CALL = 1
    MESSAGE_TYPE_METHOD_RETURN = 2
    MESSAGE_TYPE_ERROR = 3
    MESSAGE_TYPE_SIGNAL = 4

    FIELD_PATH = 1
    FIELD_INTERFACE = 2
    FIELD_MEMBER = 3
    FIELD_ERROR_NAME = 4
    FIELD_REPLY_SERIAL = 5
    FIELD_DESTINATION = 6
    FIELD_SENDER = 7
    FIELD_SIGNATURE = 8

    # Raised for a file that is not a pcap log of D-Bus traffic at all; a
    # single unparseable message inside a good file becomes a warning instead.
    class Error < StandardError; end

    class << self
      # Returns [warnings, log]: one warning per message that would not
      # unmarshal, and every event that did.
      def read_pcap(path)
        File.open(path, "rb") { |file| read_packets(file, path) }
      end

      private

        def read_packets(file, path)
          byte_order = read_global_header(file, path)
          converter = Converter.new
          warnings = []
          log = []
          while (packet = read_packet(file, byte_order))
            timestamp, body = packet
            result = converter.convert(timestamp, body)
            case result
            when String then warnings << result
            else log << result
            end
          end
          [warnings, log]
        end

        def read_global_header(file, path)
          header = file.read(GLOBAL_HEADER_SIZE)
          if header.nil? || header.bytesize < GLOBAL_HEADER_SIZE
            raise Error, Bustle._("Empty or truncated file")
          end

          byte_order = byte_order_of(header, path)
          link_type = header[20, 4].unpack1(byte_order == :little ? "V" : "N")
          unless [LINK_TYPE_NULL, LINK_TYPE_DBUS].include?(link_type)
            raise Error, "Incorrect link type #{link_type}"
          end

          byte_order
        end

        # A pcap file stores its magic number in its own byte order, which is
        # how we learn what that order is.
        def byte_order_of(header, path)
          case header[0, 4].unpack1("H8")
          when "d4c3b2a1" then :little
          when "a1b2c3d4" then :big
          else raise Error, "#{File.basename(path)} is not a pcap file"
          end
        end

        def read_packet(file, byte_order)
          header = file.read(PACKET_HEADER_SIZE)
          if header.nil? || header.bytesize < PACKET_HEADER_SIZE
            nil
          else
            seconds, microseconds, captured, _original = header.unpack(byte_order == :little ? "V4" : "N4")
            body = file.read(captured)
            if captured.zero? || body.nil? || body.bytesize < captured
              nil
            else
              [(seconds * 1_000_000) + microseconds, body]
            end
          end
        end
    end

    # Reads one marshalled D-Bus message off a packet body.
    #
    # This is the part upstream gets from the Haskell `dbus` package. The wire
    # format is a fixed header (byte order, message type, flags, protocol
    # version, body length, serial), an array of header fields carrying the
    # path, interface, member, destination, sender, reply serial and body
    # signature, and then the body itself — every value aligned to its own
    # width, which is what makes the format worth a dedicated reader.
    class Unmarshaller
      class Error < StandardError; end

      Message = Data.define(
        :type,
        :flags,
        :serial,
        :path,
        :interface,
        :member,
        :error_name,
        :reply_serial,
        :destination,
        :sender,
        :signature,
        :body,
      )

      ALIGNMENTS = {
        "y" => 1,
        "g" => 1,
        "v" => 1,
        "n" => 2,
        "q" => 2,
        "b" => 4,
        "i" => 4,
        "u" => 4,
        "h" => 4,
        "s" => 4,
        "o" => 4,
        "a" => 4,
        "x" => 8,
        "t" => 8,
        "d" => 8,
        "(" => 8,
        "{" => 8,
      }.freeze

      def initialize(data)
        @data = data.dup.force_encoding(Encoding::BINARY)
        @offset = 0
      end

      def message
        type, flags, body_length, serial = read_fixed_header
        fields = read_header_fields
        align(8)
        Message.new(
          type:,
          flags:,
          serial:,
          path: fields[FIELD_PATH],
          interface: fields[FIELD_INTERFACE],
          member: fields[FIELD_MEMBER],
          error_name: fields[FIELD_ERROR_NAME],
          reply_serial: fields[FIELD_REPLY_SERIAL],
          destination: fields[FIELD_DESTINATION],
          sender: fields[FIELD_SENDER],
          signature: fields[FIELD_SIGNATURE],
          body: read_body(fields[FIELD_SIGNATURE], body_length),
        )
      end

      private

        def read_fixed_header
          @byte_order = byte_order_of(read(1))
          type = read_byte
          flags = read_byte
          version = read_byte
          unless version == 1
            raise Error, "Unsupported D-Bus protocol version #{version}"
          end

          [type, flags, read_uint32, read_uint32]
        end

        def byte_order_of(marker)
          case marker
          when "l" then :little
          when "B" then :big
          else raise Error, "Invalid endianness marker #{marker.inspect}"
          end
        end

        def read_header_fields
          align(4)
          finish = @offset + read_uint32
          fields = {}
          while @offset < finish
            align(8)
            code = read_byte
            fields[code] = read_value(read_signature)
          end
          fields
        end

        # The body's own signature is a header field; a message with no
        # arguments has no signature field at all.
        def read_body(signature, body_length)
          finish = @offset + body_length
          if signature.nil?
            []
          else
            VariantFormatter.split_signature(signature).map do |type|
              Types::Variant.new(signature: type, value: read_value(type))
            end.tap { @offset = finish }
          end
        end

        def read_value(signature)
          case signature[0]
          when "y" then read_byte
          when "b" then read_aligned(4) { read_uint32 } != 0
          when "n" then read_aligned(2) { unpack(2, "s<", "s>") }
          when "q" then read_aligned(2) { unpack(2, "v", "n") }
          when "i" then read_aligned(4) { unpack(4, "l<", "l>") }
          when "u", "h" then read_aligned(4) { read_uint32 }
          when "x" then read_aligned(8) { unpack(8, "q<", "q>") }
          when "t" then read_aligned(8) { unpack(8, "Q<", "Q>") }
          when "d" then read_aligned(8) { unpack(8, "E", "G") }
          when "s", "o" then read_string
          when "g" then read_signature
          when "v" then read_variant
          when "a" then read_array(signature)
          when "(" then read_structure(signature)
          when "{" then read_dict_entry(signature)
          else raise Error, "Unknown type code #{signature[0].inspect}"
          end
        end

        def read_variant
          read_signature.then { |signature| Types::Variant.new(signature:, value: read_value(signature)) }
        end

        # An array is a byte count followed by elements packed at their own
        # alignment — so the padding after the count belongs to the first
        # element and not to the array.
        def read_array(signature)
          align(4)
          length = read_uint32
          element = signature[1..]
          align(ALIGNMENTS.fetch(element[0], 1))
          finish = @offset + length
          items = []
          items << read_value(element) while @offset < finish
          if element.start_with?("{")
            items.to_h
          else
            items
          end
        end

        def read_structure(signature)
          align(8)
          VariantFormatter.split_signature(signature[1..-2]).map { |type| read_value(type) }
        end

        def read_dict_entry(signature)
          align(8)
          VariantFormatter.split_signature(signature[1..-2]).map { |type| read_value(type) }
        end

        def read_string
          align(4)
          read_uint32.then do |length|
            read(length).force_encoding(Encoding::UTF_8).tap { read(1) }
          end
        end

        def read_signature
          read(read_byte).force_encoding(Encoding::UTF_8).tap { read(1) }
        end

        def read_byte = read(1).unpack1("C")

        def read_uint32 = unpack(4, "V", "N")

        def read_aligned(width, &block)
          align(width)
          block.call
        end

        def unpack(width, little, big)
          if @byte_order == :little
            read(width).unpack1(little)
          else
            read(width).unpack1(big)
          end
        end

        def read(length)
          if @offset + length > @data.bytesize
            raise Error, "Truncated D-Bus message"
          end

          @data.byteslice(@offset, length).tap { @offset += length }
        end

        def align(width)
          @offset = ((@offset + width - 1) / width) * width
        end
    end

    # Turns marshalled messages into model events, remembering the calls that
    # are still waiting for a reply.
    class Converter
      def initialize
        @pending = {}
      end

      # Returns a Types::Detailed, or a String describing why the message
      # could not be read — which is upstream's Either String DetailedEvent.
      def convert(timestamp, body)
        bustlify(timestamp, body, Unmarshaller.new(body).message)
      rescue Unmarshaller::Error, Error => e
        e.message
      end

      private

        def bustlify(timestamp, body, message)
          event = event_for(timestamp, body, message)
          Types::Detailed.new(
            timestamp:,
            event:,
            message_size: body.bytesize,
            body: message.body,
          )
        end

        def event_for(timestamp, body, message)
          case message.type
          when MESSAGE_TYPE_METHOD_CALL then method_call(timestamp, body, message)
          when MESSAGE_TYPE_METHOD_RETURN then method_return(message)
          when MESSAGE_TYPE_ERROR then error_return(message)
          when MESSAGE_TYPE_SIGNAL then signal(message)
          else raise Error, "Unknown message type #{message.type}"
          end
        end

        def method_call(timestamp, body, message)
          Types::MethodCall.new(
            serial:      message.serial,
            sender:      sender_of(message),
            destination: destination_of(message, "method.call.destination"),
            member:      member_of(message),
          ).tap do |call|
            @pending[[message.sender, message.serial]] = Types::Detailed.new(
              timestamp:,
              event: call,
              message_size: body.bytesize,
              body: message.body,
            )
          end
        end

        def method_return(message)
          call = pop_matching_call(message)
          name_owner_reply(call, message) ||
            Types::MethodReturn.new(
              in_reply_to: call,
              sender:      sender_of(message),
              destination: destination_of(message, "method.return.destination"),
            )
        end

        def error_return(message)
          Types::ErrorReturn.new(
            in_reply_to: pop_matching_call(message),
            sender:      sender_of(message),
            destination: destination_of(message, "method.error.destination"),
          )
        end

        def signal(message)
          name_owner_changed(message) ||
            Types::Signal.new(
              sender:             sender_of(message),
              member:             member_of(message),
              signal_destination: message.destination&.then { |name| Types.tagged_bus_name(name) },
            )
        end

        # The reply tells us nothing but its serial; the call it answers was
        # logged under the serial and the name of whoever sent it. A log made
        # by the recorder itself may not know that sender, so a miss falls back
        # to the call filed under no sender at all.
        def pop_matching_call(message)
          @pending.delete([message.destination, message.reply_serial]).then do |call|
            if call.nil? && !message.destination.nil?
              @pending.delete([nil, message.reply_serial])
            else
              call
            end
          end
        end

        def name_owner_changed(message)
          if name_owner_changed?(message)
            name, old_owner, new_owner = message.body.map { |argument| bus_name_or_nil(argument.value) }
            noc_for(name, old_owner, new_owner)
          end
        end

        def name_owner_changed?(message)
          message.sender == Types::DBUS_NAME &&
            message.interface == Types::DBUS_INTERFACE &&
            message.member == "NameOwnerChanged" &&
            message.body.length == 3
        end

        # A reply to org.freedesktop.DBus.GetNameOwner says who owns a name,
        # which is the only way a log that started mid-conversation learns it.
        # Upstream assumes the reply carries an owner; a reply that does not is
        # left as the plain method return it is.
        def name_owner_reply(call, message)
          if call&.event.is_a?(Types::MethodCall) && call.event.member.member_name == "GetNameOwner"
            owned = bus_name_or_nil(call.body.first&.value)
            owner = bus_name_or_nil(message.body.first&.value)
            if owned && owner
              noc_for(owned, nil, owner)
            end
          end
        end

        # An empty string in a NameOwnerChanged argument means "nobody", and
        # is not a bus name.
        def bus_name_or_nil(value)
          if value.nil? || value.to_s.empty?
            nil
          else
            value.to_s
          end
        end

        def noc_for(name, old_owner, new_owner)
          if name.start_with?(":")
            unique_noc(name, old_owner, new_owner)
          else
            Types::NameChanged.new(changed_name: Types.other_name(name), change: change_for(old_owner, new_owner))
          end
        end

        def unique_noc(name, old_owner, new_owner)
          case [old_owner.nil?, new_owner.nil?]
          when [true, false] then Types::Connected.new(actor: Types.unique_name(name))
          when [false, true] then Types::Disconnected.new(actor: Types.unique_name(name))
          else raise Error, "Nonsensical NameOwnerChanged for #{name}"
          end
        end

        def change_for(old_owner, new_owner)
          case [old_owner.nil?, new_owner.nil?]
          when [false, true] then Types::Released.new(old_owner: Types.unique_name(old_owner))
          when [false, false]
            Types::Stolen.new(old_owner: Types.unique_name(old_owner), new_owner: Types.unique_name(new_owner))
          when [true, false] then Types::Claimed.new(new_owner: Types.unique_name(new_owner))
          else raise Error, "Nonsensical NameOwnerChanged with no owners"
          end
        end

        # Upstream substitutes placeholder names like "sen.der" when a message
        # has no sender or destination, which happens for messages to and from
        # the recorder itself.
        def sender_of(message) = Types.tagged_bus_name(message.sender || "sen.der")

        def destination_of(message, fallback) = Types.tagged_bus_name(message.destination || fallback)

        def member_of(message)
          Types::Member.new(path: message.path, interface: message.interface, member_name: message.member)
        end
    end
  end
end
