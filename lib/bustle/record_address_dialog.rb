# frozen_string_literal: true

require "adwaita"

require_relative "translation"

module Bustle
  # Asks for the address of a bus to record.
  #
  # Ported from upstream's Bustle/UI/RecordAddressDialog.hs and
  # data/RecordAddressDialog.ui: a modal dialog with an address entry, a
  # Cancel button and a Record button that is insensitive until the entry has
  # something in it. Upstream's comment notes it would rather validate the
  # address with g_dbus_is_supported_address(), and settles for a non-empty
  # string; so does this.
  #
  # Two details differ because GTK4 does. There is no GtkDialog any more, so
  # this is an Adwaita::Window whose header bar carries the two buttons in
  # place of an action area. And Adwaita::EntryRow has no placeholder of its
  # own — an empty row shows its title instead — so upstream's placeholder,
  # the one its translator comment says to leave alone but for the "e.g.",
  # becomes the description of the group the row sits in, where it is visible
  # for the same reason upstream's placeholder was.
  class RecordAddressDialog
    WIDTH = 600

    def initialize(on_record:)
      @on_record = on_record
    end

    def present(parent)
      build.tap do |win|
        win.transient_for = parent
        win.present
      end
    end

    def build
      window.tap do |win|
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = group

          header_bar.tap do |bar|
            bar.pack_start(cancel_button)
            bar.pack_end(record_button)

            cancel_button.signal_connect("clicked") { window.close }
            record_button.signal_connect("clicked") { record }
          end

          group.add(address_row)

          address_row.signal_connect("changed") { refresh_sensitivity }
        end
      end
    end

    def window
      @window ||= Adwaita::Window.new.tap do |win|
        win.title = Bustle._("Record Address")
        win.modal = true
        win.resizable = false
        win.default_width = WIDTH
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
        bar.show_start_title_buttons = false
      end
    end

    def cancel_button
      @cancel_button ||= Gtk::Button.new.tap do |button|
        button.label = Bustle._("_Cancel")
        button.use_underline = true
      end
    end

    def record_button
      @record_button ||= Gtk::Button.new.tap do |button|
        button.label = Bustle._("_Record")
        button.use_underline = true
        button.sensitive = false
        button.add_css_class("suggested-action")
      end
    end

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap do |widget|
        widget.description = Bustle._(
          "e.g. unix:abstract=/tmp/dbus-E5RlEB5Tzu,guid= b1c1921b62283b7b612b57305b20cc28",
        )
        widget.margin_top = 12
        widget.margin_bottom = 12
        widget.margin_start = 12
        widget.margin_end = 12
      end
    end

    def address_row
      @address_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = Bustle._("Address:")
      end
    end

    private

      def address = address_row.text.to_s

      def refresh_sensitivity
        record_button.sensitive = !address.empty?
      end

      def record
        address.then do |chosen|
          window.close
          @on_record.call(chosen)
        end
      end
  end
end
