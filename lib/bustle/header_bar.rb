# frozen_string_literal: true

require "adwaita"

require_relative "menus"
require_relative "translation"

module Bustle
  # The window's title bars.
  #
  # Ported from the header, headerPaned and sidebarHeader widgets in
  # data/bustle.ui. Upstream pairs two GtkHeaderBars inside a GtkPaned so the
  # statistics sidebar gets a title bar of its own, lined up with the paned
  # below it; this port keeps the main header as the window's top bar and
  # gives the sidebar its own small header inside the sidebar pane, which is
  # how a GTK4 app arranges the same thing.
  #
  # The log's filename is the title and its directory the subtitle, which is
  # what upstream's headerTitle and headerSubtitle labels hold.
  class HeaderBar
    def initialize(menus:)
      @menus = menus
    end

    def build
      header_bar.tap do |bar|
        bar.pack_start(open_button)
        bar.pack_end(main_menu_button)
        bar.pack_end(export_button)
        bar.title_widget = window_title
      end
    end

    # The sidebar's header, which is nothing but a switcher between the three
    # statistics tables.
    def build_sidebar_header(stack)
      sidebar_header.tap do |bar|
        bar.title_widget = stack_switcher.tap { |switcher| switcher.stack = stack }
      end
    end

    def set_title(title, subtitle)
      window_title.title = title
      window_title.subtitle = subtitle
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def sidebar_header
      @sidebar_header ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
        bar.show_start_title_buttons = false
      end
    end

    def stack_switcher = @stack_switcher ||= Gtk::StackSwitcher.new

    def window_title = @window_title ||= Adwaita::WindowTitle.new(Bustle._("Bustle"), "")

    def open_button
      @open_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "document-open-symbolic"
        button.tooltip_text = Bustle._("Open an existing log")
        button.menu_model = @menus.open_menu
      end
    end

    def export_button
      @export_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "document-send-symbolic"
        button.tooltip_text = Bustle._("Export as PDF")
        button.action_name = "win.export-pdf"
      end
    end

    def main_menu_button
      @main_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "open-menu-symbolic"
        button.tooltip_text = Bustle._("Main Menu")
        button.menu_model = @menus.main_menu
      end
    end
  end
end
