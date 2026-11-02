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
      status_page.tap do |page|
        page.child = spinner
      end
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = Bustle._("Waiting for D-Bus traffic; please hold…")
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
