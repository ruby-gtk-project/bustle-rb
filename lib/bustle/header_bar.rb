# frozen_string_literal: true

require "adwaita"

require_relative "marquee"
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
  # The controls are upstream's, in upstream's order: the Record menu button
  # and the Stop button that replaces it while a recording runs, then Open;
  # the spinner and the two title labels in the middle; then Save and Export
  # at the end. Upstream's headerTitle and headerSubtitle are GtkLabels set
  # with labelSetMarkup, not an AdwWindowTitle, and they have to stay labels:
  # the recording subtitle is `Logged <b>%u</b> messages`, which an
  # AdwWindowTitle would show with the tags in it.
  class HeaderBar
    def initialize(menus:)
      @menus = menus
    end

    def build
      header_bar.tap do |bar|
        bar.pack_start(record_button)
        bar.pack_start(stop_button)
        bar.pack_start(open_button)
        bar.pack_end(main_menu_button)
        bar.pack_end(export_button)
        bar.pack_end(save_button)
        bar.title_widget = title_box

        title_box.tap do |box|
          box.append(spinner)
          box.append(label_box)

          label_box.tap do |labels|
            labels.append(title_label)
            labels.append(subtitle_label)
          end
        end
      end
    end

    # The sidebar's header, which is nothing but a switcher between the three
    # statistics tables.
    def build_sidebar_header(stack)
      sidebar_header.tap do |bar|
        bar.title_widget = stack_switcher.tap { |switcher| switcher.stack = stack }
      end
    end

    # The log's filename and its directory, as plain text: both labels take
    # markup, so anything that is not markup has to be escaped on the way in.
    def set_title(title, subtitle)
      title_label.label = Marquee.escape(title).to_markup
      subtitle_label.label = Marquee.escape(subtitle).to_markup
    end

    # Upstream's startRecording: Record and Open go away, Stop takes their
    # place and the keyboard with it, and the spinner starts.
    def start_recording(title)
      record_button.visible = false
      open_button.visible = false
      stop_button.visible = true
      stop_button.grab_focus
      spinner.spinning = true
      title_label.label = title
      set_message_count(0)
    end

    # Upstream's finishedRecording, which puts all of that back.
    def finish_recording
      record_button.visible = true
      open_button.visible = true
      stop_button.visible = false
      spinner.spinning = false
    end

    def clear_title
      title_label.label = ""
      subtitle_label.label = ""
    end

    def set_message_count(count)
      subtitle_label.label = format(Bustle._("Logged <b>%u</b> messages"), count)
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def sidebar_header
      @sidebar_header ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
        bar.show_start_title_buttons = false
      end
    end

    def stack_switcher = @stack_switcher ||= Gtk::StackSwitcher.new

    def title_box
      @title_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.valign = :center
      end
    end

    def label_box = @label_box ||= Gtk::Box.new(:vertical, 0)

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.ellipsize = :end
        label.single_line_mode = true
        label.add_css_class("title")
      end
    end

    def subtitle_label
      @subtitle_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.ellipsize = :end
        label.single_line_mode = true
        label.add_css_class("subtitle")
      end
    end

    # Upstream's headerSpinner sits beside the title labels rather than in a
    # corner, so a quiet bus still looks like something is happening.
    def spinner
      @spinner ||= Gtk::Spinner.new.tap do |widget|
        widget.valign = :center
      end
    end

    def record_button
      @record_button ||= Gtk::MenuButton.new.tap do |button|
        button.child = record_button_content
        button.tooltip_text = Bustle._("Record a new log")
        button.menu_model = @menus.record_menu
        button.add_css_class("suggested-action")
      end
    end

    def record_button_content
      @record_button_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "media-record-symbolic"
        content.label = Bustle._("_Record")
        content.use_underline = true
      end
    end

    def stop_button
      @stop_button ||= Gtk::Button.new.tap do |button|
        button.label = Bustle._("_Stop")
        button.use_underline = true
        button.visible = false
        button.add_css_class("destructive-action")
      end
    end

    def open_button
      @open_button ||= Gtk::MenuButton.new.tap do |button|
        button.icon_name = "document-open-symbolic"
        button.tooltip_text = Bustle._("Open an existing log")
        button.menu_model = @menus.open_menu
      end
    end

    def save_button
      @save_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "document-save-symbolic"
        button.tooltip_text = Bustle._("Save")
        button.action_name = "win.#{Menus::SAVE_ACTION}"
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
