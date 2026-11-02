# frozen_string_literal: true

require "adwaita"

require_relative "rb/version"
require_relative "translation"
require_relative "util"

module Bustle
  # Who wrote this and under what terms.
  #
  # Ported from upstream's Bustle/UI/AboutDialog.hs, including its list of
  # authors and its habit of reading the licence text off disk so the dialog
  # can show the whole thing. A missing licence file is a warning rather than
  # a crash, exactly as upstream's handler makes it.
  class AboutDialog
    WEBSITE = "https://www.freedesktop.org/wiki/Software/Bustle/"
    COPYRIGHT = "© 2008–2017 Will Thompson, Collabora Ltd. and contributors"
    LOGO_ICON_NAME = "org.rubygtkproject.Bustle"

    AUTHORS = [
      "Will Thompson <will@willthompson.co.uk>",
      "Dafydd Harries",
      "Chris Lamb",
      "Marc Kleine-Budde",
      "Cosimo Alfarano",
      "Sergei Trofimovich",
      "Alex Merry",
      "Philip Withnall",
      "Jonny Lamb",
      "Daniel Firth",
    ].freeze

    # The Ruby port's own licence file, which carries upstream's terms.
    LICENCE_PATHS = [
      File.expand_path("../../LICENSE", __dir__),
      File.expand_path("../../LICENSE.md", __dir__),
    ].freeze

    def present(parent)
      dialog.tap do |about|
        about.transient_for = parent
        about.present
      end
    end

    def dialog
      @dialog ||= Gtk::AboutDialog.new.tap do |about|
        about.program_name = Bustle._("Bustle")
        about.version = Rb::Version::VERSION
        about.comments = Bustle._("Someone's favourite D-Bus profiler")
        about.website = WEBSITE
        about.authors = AUTHORS
        about.copyright = COPYRIGHT
        about.logo_icon_name = LOGO_ICON_NAME
        about.modal = true
        about.license = licence
      end
    end

    private

      def licence
        LICENCE_PATHS.find { |path| File.exist?(path) }.then do |path|
          if path
            File.read(path)
          end
        end
      rescue SystemCallError, IOError => e
        Util.warn(e.message)
        nil
      end
  end
end
