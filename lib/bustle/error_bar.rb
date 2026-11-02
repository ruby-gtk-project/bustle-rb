# frozen_string_literal: true

require "adwaita"

require_relative "marquee"
require_relative "translation"

module Bustle
  # The strip across the top of the window that explains what went wrong.
  #
  # Ported from upstream's errorBar/errorBarTitle/errorBarDetails in
  # data/bustle.ui: a GtkInfoBar with `message_type=error`, a close button of
  # GTK's own, and a vertical box holding a bold title and small details, both
  # of them `selectable="True"`.
  #
  # GTK4 deprecated GtkInfoBar, and its libadwaita replacement, AdwBanner,
  # carries one line of unselectable text in the accent colour — none of the
  # three things upstream chose here. So the bar is a box in the error colours
  # with the same two labels inside it, selectable as upstream's are: the one
  # thing a user does with "Could not read '/path': …" is select it and paste
  # it into a bug report. The close button carries GTK's own icon rather than
  # a label, as the info bar's built-in one did, so it needs no translation.
  #
  # Upstream hides the details label when there are none, and so does this.
  class ErrorBar
    CSS_CLASS = "bustle-error-bar"

    CSS = <<~CSS
      .#{CSS_CLASS} {
        background-color: var(--error-bg-color);
        color: var(--error-fg-color);
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
      ErrorBar.install_css
      container.tap do |bar|
        bar.append(text_box)
        bar.append(close_button)

        text_box.tap do |box|
          box.append(title_label)
          box.append(details_label)
        end

        close_button.signal_connect("clicked") { hide }
      end
    end

    # Shows a title, and the details below it if there are any.
    def show(title, details = nil)
      title_label.label = Marquee.b(Marquee.escape(title)).to_markup
      details_label.label = Marquee.small(Marquee.escape(details.to_s)).to_markup
      details_label.visible = !details.nil?
      container.visible = true
    end

    def hide
      container.visible = false
    end

    # Upstream's content area spaces the text 16px from the action area, and
    # the box inside it spaces the two labels 6px apart.
    def container
      @container ||= Gtk::Box.new(:horizontal, 16).tap do |box|
        box.visible = false
        box.add_css_class(CSS_CLASS)
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def text_box
      @text_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.hexpand = true
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.selectable = true
        label.halign = :start
        label.xalign = 0
      end
    end

    def details_label
      @details_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.selectable = true
        label.halign = :start
        label.xalign = 0
      end
    end

    def close_button
      @close_button ||= Gtk::Button.new(icon_name: "window-close-symbolic").tap do |button|
        button.add_css_class("flat")
        button.valign = :start
      end
    end
  end
end
