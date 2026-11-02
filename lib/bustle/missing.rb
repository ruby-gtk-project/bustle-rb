# frozen_string_literal: true

require_relative "translation"

module Bustle
  # Human-readable byte counts for the statistics pane's size columns.
  #
  # Ported from upstream's Bustle/Missing.hs, which exists only because
  # gtk2hs never bound g_format_size(). The port reimplements that function's
  # output rather than calling it: SI units (powers of 1000, as GLib's default
  # flags select), one decimal place, and a byte count spelled out in full
  # below a kilobyte. D-Bus caps messages at 2**27 bytes, so megabytes are as
  # far as this realistically goes.
  module Missing
    KILOBYTE = 1000
    UNITS = ["kB", "MB", "GB", "TB", "PB", "EB"].freeze

    class << self
      def format_size(size)
        if size < KILOBYTE
          format_bytes(size)
        else
          format_scaled(size)
        end
      end

      private

        def format_bytes(size)
          if size == 1
            Bustle._("%u byte") % size
          else
            Bustle._("%u bytes") % size
          end
        end

        # Divides by 1000 until the number fits one unit, exactly as
        # g_format_size() does, so 1000 bytes reads "1.0 kB" and not "1000
        # bytes".
        def format_scaled(size)
          scaled = size.to_f
          unit = UNITS.first
          UNITS.each do |candidate|
            unit = candidate
            if scaled < KILOBYTE * KILOBYTE
              break
            end

            scaled /= KILOBYTE
          end
          format("%<size>.1f %<unit>s", size: scaled / KILOBYTE, unit: unit)
        end
    end
  end
end
