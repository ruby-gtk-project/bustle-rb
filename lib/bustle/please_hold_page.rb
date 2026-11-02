# frozen_string_literal: true

require "adwaita"

require_relative "translation"

module Bustle
  # The page shown while a recording is running but no traffic has arrived
  # yet.
  #
  # Ported from upstream's PleaseHoldPage in data/bustle.ui, which is a single
  # centred label. The port adds the spinner upstream keeps in its header bar,
  # so a quiet bus still looks like something is happening.
  class PleaseHoldPage
    def build
      status_page.tap do
        holding_box.tap do |box|
          box.append(holding_label)
          box.append(spinner)
        end
      end
    end

    # Upstream's label is a single translatable string with its markup
    # inside it — `<big><b>…</b></big>` is part of the msgid, not something
    # the .ui file adds around it — so the page's title cannot be an
    # AdwStatusPage title, which takes plain text. It is a label that takes
    # markup, exactly as upstream's is.
    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.child = holding_box
      end
    end

    def holding_box
      @holding_box ||= Gtk::Box.new(:vertical, 18).tap do |box|
        box.valign = :center
      end
    end

    def holding_label
      @holding_label ||= Gtk::Label.new.tap do |label|
        label.label = Bustle._("<big><b>Waiting for D-Bus traffic; please hold…</b></big>")
        label.use_markup = true
        label.wrap = true
        label.justify = :center
      end
    end

    def spinner
      @spinner ||= Gtk::Spinner.new.tap do |widget|
        widget.width_request = 32
        widget.height_request = 32
        widget.halign = :center
        widget.spinning = true
      end
    end
  end
end
