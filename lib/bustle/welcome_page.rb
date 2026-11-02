# frozen_string_literal: true

require "adwaita"

require_relative "translation"

module Bustle
  # The empty state: what the window shows before a log is opened.
  #
  # Ported from upstream's InstructionsPage in data/bustle.ui — the app icon,
  # a welcome, and the two ways of getting a log to look at. Upstream stacks
  # the icon and labels in a GtkBox; the port uses an Adwaita status page,
  # which is the same arrangement with the spacing already decided.
  class WelcomePage
    ICON_NAME = "org.rubygtkproject.Bustle-symbolic"

    def build
      status_page
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = ICON_NAME
        page.title = Bustle._("Welcome to Bustle")
        page.child = description_label
      end
    end

    # The description is markup, so it goes in a label of its own rather than
    # in the status page's own description, which takes plain text.
    def description_label
      @description_label ||= Gtk::Label.new.tap do |label|
        label.label = instructions
        label.use_markup = true
        label.justify = :center
        label.wrap = true
        label.add_css_class("dim-label")
      end
    end

    private

      def instructions
        Bustle._(
          "Start recording D-Bus activity with the <b>Record</b> button above\n" \
          " You can also run <i>dbus-monitor --pcap</i> from the command line",
        )
      end
  end
end
