# frozen_string_literal: true

require "glib2"

module Bustle
  # Human-readable byte counts for the statistics pane's size columns.
  #
  # Ported from upstream's Bustle/Missing.hs, which is a one-function FFI
  # binding for g_format_size() — the module exists only because gtk2hs never
  # bound it. The Ruby bindings do, so this calls the same function rather
  # than reimplementing it.
  #
  # That matters for more than tidiness: g_format_size()'s strings ("%u byte",
  # "%.1f kB" and the rest) live in GLib's own message catalogue and are
  # already translated into every language GLib ships. Spelling them again in
  # Bustle's domain would mean shipping untranslated English for sizes in
  # every locale.
  module Missing
    class << self
      def format_size(size) = GLib.format_size(size)
    end
  end
end
