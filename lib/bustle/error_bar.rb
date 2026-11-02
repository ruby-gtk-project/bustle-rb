# frozen_string_literal: true

require "adwaita"

require_relative "marquee"
require_relative "translation"

module Bustle
  # The strip across the top of the window that explains what went wrong.
  #
  # Ported from upstream's errorBar/errorBarTitle/errorBarDetails in
  # data/bustle.ui, a GtkInfoBar with a bold title and small details. GTK4
  # deprecated GtkInfoBar in favour of AdwBanner, which carries a single line
  # of text; the title goes there and the details — the loader's complaint
  # about a particular file, say — go in a dim label underneath, because
  # losing them would leave the user with nothing to act on.
  #
  # Upstream hides the details label when there are none, and so does this.
  class ErrorBar
    def build
      container.tap do |box|
        box.append(banner)
        box.append(details_label)

        banner.signal_connect("button-clicked") { hide }
      end
    end

    # Shows a title, and the details below it if there are any.
    def show(title, details = nil)
      banner.title = Marquee.b(Marquee.escape(title)).to_markup
      banner.revealed = true
      details_label.label = Marquee.small(Marquee.escape(details.to_s)).to_markup
      details_label.visible = !details.nil?
      container.visible = true
    end

    def hide
      banner.revealed = false
      container.visible = false
    end

    def container
      @container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.visible = false
      end
    end

    def banner
      @banner ||= Adwaita::Banner.new("").tap do |widget|
        widget.button_label = Bustle._("_Close")
        widget.use_markup = true
      end
    end

    def details_label
      @details_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.xalign = 0
        label.margin_start = 12
        label.margin_end = 12
        label.margin_bottom = 6
        label.add_css_class("dim-label")
      end
    end
  end
end
