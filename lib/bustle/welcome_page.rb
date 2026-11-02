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
  #
  # All three of upstream's children carry dim-label, and the icon is 256
  # pixels: upstream's own AppStream caption for this screen is "Relax with
  # this soothing greyscale welcome page", so the dimming is the design and
  # not an accident. A status page builds its icon and title itself, so there
  # is no widget here to add a class to; the class goes on the page and the
  # CSS reaches the two nodes libadwaita names, .icon and .title.
  class WelcomePage
    ICON_NAME = "org.rubygtkproject.Bustle-symbolic"

    CSS_CLASS = "bustle-welcome"

    # dim-label is 55% opacity in libadwaita's stylesheet, which is what
    # upstream's three dimmed children get.
    DIM_OPACITY = "0.55"

    ICON_SIZE = 256

    CSS = <<~CSS
      .#{CSS_CLASS} .icon,
      .#{CSS_CLASS} .title {
        opacity: #{DIM_OPACITY};
      }

      .#{CSS_CLASS} .icon {
        -gtk-icon-size: #{ICON_SIZE}px;
      }
    CSS

    class << self
      # One provider for the whole display, added once however many windows
      # ask for it.
      def install_css
        unless @installed
          @installed = true
          Gtk::StyleContext.add_provider_for_display(
            Gdk::Display.default,
            css_provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end

      def css_provider
        @css_provider ||= Gtk::CssProvider.new.tap { |provider| provider.load(data: CSS) }
      end
    end

    def build
      WelcomePage.install_css
      status_page
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = ICON_NAME
        page.title = Bustle._("Welcome to Bustle")
        page.child = description_label
        page.add_css_class(CSS_CLASS)
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
