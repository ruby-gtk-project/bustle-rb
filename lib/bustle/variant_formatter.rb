# frozen_string_literal: true

require_relative "types"

module Bustle
  # Renders a D-Bus value the way the details pane shows it.
  #
  # Ported from upstream's Bustle/VariantFormatter.hs. The three styles are
  # upstream's: BARE for a value nested inside a container, SIGNATURE for a
  # top-level argument ("@s \"hello\""), and ANGLE_BRACKETS for a value inside
  # a variant ("<@u 7>"). Upstream dispatches on the dbus library's Type;
  # the port dispatches on the signature the unmarshaller recorded alongside
  # the value, which amounts to the same thing and keeps the formatter free of
  # any D-Bus binding.
  module VariantFormatter
    BARE = :bare
    SIGNATURE = :signature
    ANGLE_BRACKETS = :angle_brackets

    class << self
      def format_variant(style, variant)
        formatted = format_value(variant.signature, variant.value)
        case style
        when BARE then formatted
        when SIGNATURE then "@#{variant.signature} #{formatted}"
        when ANGLE_BRACKETS then "<@#{variant.signature} #{formatted}>"
        end
      end

      # Splits "ias(ii)" into ["i", "as", "(ii)"] — one complete type per
      # entry, which is what a body signature and a struct both need.
      def split_signature(signature)
        [].tap do |types|
          offset = 0
          while offset < signature.length
            length = type_length(signature, offset)
            types << signature[offset, length]
            offset += length
          end
        end
      end

      private

        def format_value(signature, value)
          case signature
          when "b" then format_boolean(value)
          when "y", "n", "q", "i", "u", "x", "t" then value.to_s
          when "d" then value.to_f.to_s
          when "s", "o", "g" then value.to_s.inspect
          when "h" then "<fd>"
          when "v" then format_variant(ANGLE_BRACKETS, value)
          when "ay" then format_byte_array(value)
          when /\Aa\{/ then format_dictionary(signature, value)
          when /\Aa/ then format_array(signature, value)
          when /\A\(/ then format_structure(signature, value)
          else value.to_s
          end
        end

        # Haskell's `show` for Bool, which the details pane has always shown.
        def format_boolean(value)
          if value
            "True"
          else
            "False"
          end
        end

        # A byte array of printable characters is almost always a string the
        # sender did not want marshalling as one, so show it as b"…" and save
        # the reader decoding 40 integers.
        def format_byte_array(bytes)
          bytes.map { |byte| byte.chr("BINARY") }.join.then do |packed|
            if printable?(packed)
              "b#{packed.force_encoding("UTF-8").inspect}"
            else
              format_array("ay", bytes)
            end
          end
        end

        def printable?(packed)
          packed.force_encoding("UTF-8").valid_encoding? &&
            packed.force_encoding("UTF-8").each_char.all? { |char| char == "\0" || printable_char?(char) }
        end

        def printable_char?(char) = !char.match?(/[[:cntrl:]]/)

        def format_array(signature, items)
          element = signature[1..]
          items.map { |item| format_value(element, item) }
               .join(", ")
               .then { |formatted| "[#{formatted}]" }
        end

        def format_dictionary(signature, pairs)
          key_type = split_signature(signature[2..-2]).first
          value_type = split_signature(signature[2..-2]).last
          pairs.map { |key, value| "#{format_value(key_type, key)}: #{format_value(value_type, value)}" }
               .join(", ")
               .then { |formatted| "{#{formatted}}" }
        end

        # A one-element structure prints as "(x,)", as in Python and in
        # upstream, so it cannot be mistaken for a parenthesised value.
        def format_structure(signature, items)
          types = split_signature(signature[1..-2])
          formatted = types.zip(items).map { |type, item| format_value(type, item) }
          case formatted.length
          when 0 then "()"
          when 1 then "(#{formatted.first},)"
          else "(#{formatted.join(", ")})"
          end
        end

        def type_length(signature, offset)
          case signature[offset]
          when "a" then 1 + type_length(signature, offset + 1)
          when "(", "{" then container_length(signature, offset)
          else 1
          end
        end

        def container_length(signature, offset)
          closing = {"(" => ")", "{" => "}"}.fetch(signature[offset])
          depth = 0
          length = 0
          signature[offset..].each_char do |char|
            length += 1
            case char
            when signature[offset] then depth += 1
            when closing then depth -= 1
            end
            if depth.zero?
              break
            end
          end
          length
        end
    end
  end
end
