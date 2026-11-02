# frozen_string_literal: true

require "adwaita"

require_relative "translation"

module Bustle
  # The "open a log" file chooser.
  #
  # Ported from upstream's showOpenDialog in Bustle/UI.hs, which is a
  # GtkFileChooserDialog in Open mode. GTK4 replaced that with GtkFileDialog,
  # whose callback hands back the chosen file; the filters are the port's
  # addition, and come from the MIME type the desktop entry already claims.
  class OpenDialog
    PCAP_MIME_TYPE = "application/vnd.tcpdump.pcap"
    LOG_PATTERNS = ["*.bustle", "*.pcap"].freeze

    def initialize(on_chosen:)
      @on_chosen = on_chosen
    end

    def present(parent)
      dialog.open(parent, nil) do |_source, result|
        @on_chosen.call(dialog.open_finish(result).path)
      rescue GLib::Error
        # The user dismissed the chooser, which is not worth reporting.
        nil
      end
    end

    def dialog
      @dialog ||= Gtk::FileDialog.new.tap do |chooser|
        chooser.title = Bustle._("Open a Log")
        chooser.modal = true
        chooser.filters = OpenDialog.filters
      end
    end

    class << self
      # Shared with the pair-of-logs dialog, which chooses the same kind of
      # file twice.
      def filters
        Gio::ListStore.new(Gtk::FileFilter).tap do |list|
          list.append(log_filter)
          list.append(all_filter)
        end
      end

      private

        def log_filter
          Gtk::FileFilter.new.tap do |filter|
            filter.name = Bustle._("D-Bus logs")
            filter.add_mime_type(PCAP_MIME_TYPE)
            LOG_PATTERNS.each { |pattern| filter.add_pattern(pattern) }
          end
        end

        def all_filter
          Gtk::FileFilter.new.tap do |filter|
            filter.name = Bustle._("All files")
            filter.add_pattern("*")
          end
        end
    end
  end
end
