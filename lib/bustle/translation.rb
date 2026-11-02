# frozen_string_literal: true

module Bustle
  # Message catalogue lookup.
  #
  # Ported from upstream's Bustle/Translation.hs (and the GetText.hs plumbing
  # that found the catalogue directory at build time). Upstream binds the
  # "bustle" gettext domain and routes every user-visible string through `__`;
  # here `Translation.tr` is that function, and the catalogue is read straight
  # out of the `po/` directory shipped with the gem, so the port needs no
  # compiled .mo files and no gettext dependency.
  #
  # po/LINGUAS lists one language (en), so in practice this translates English
  # into Will Thompson's English — "%s – Bustle" with an en dash. A locale with
  # no catalogue falls back to the msgid, which is the untranslated string.
  module Translation
    PO_DIR = File.expand_path("../../po", __dir__)

    class << self
      # Picks the catalogue for the current locale, as gettext would from
      # LC_ALL/LC_MESSAGES/LANG. Called once at startup; `tr` works before it
      # (untranslated), so nothing depends on the ordering.
      def init(locale: nil)
        @language = language_of(locale || ENV["LC_ALL"] || ENV["LC_MESSAGES"] || ENV["LANG"] || "")
        @catalogue = nil
        @language
      end

      def tr(msgid) = catalogue.fetch(msgid, msgid)

      def language = @language ||= language_of(ENV["LC_ALL"] || ENV["LC_MESSAGES"] || ENV["LANG"] || "")

      def catalogue = @catalogue ||= load_catalogue(language)

      def languages = File.readlines(File.join(PO_DIR, "LINGUAS")).flat_map(&:split)

      private

        # "en_GB.UTF-8@variant" picks the "en_GB" catalogue if there is one and
        # "en" otherwise, which is the gettext search order.
        def language_of(locale)
          locale.to_s.split(/[.@]/).first.to_s
        end

        def load_catalogue(language)
          candidates(language).filter_map { |name| po_path(name) }
                              .first
                              .then do |path|
            if path
              parse_po(File.read(path, encoding: "UTF-8"))
            else
              {}
            end
          end
        end

        def candidates(language)
          [language, language.split("_").first].compact.reject(&:empty?).uniq
        end

        def po_path(name)
          File.join(PO_DIR, "#{name}.po").then do |path|
            if File.exist?(path) && languages.include?(name)
              path
            end
          end
        end

        # A small PO reader: msgid/msgstr pairs, each possibly continued over
        # following string lines. The header entry (empty msgid) and entries
        # with an empty translation are dropped, so they fall back to the
        # msgid like an untranslated string.
        def parse_po(source)
          entries = {}
          key = nil
          field = nil
          source.each_line do |line|
            stripped = line.strip
            case stripped
            when /\Amsgid\s+"(.*)"\z/
              key = unescape(Regexp.last_match(1))
              field = :msgid
              entries[key] = ""
            when /\Amsgstr\s+"(.*)"\z/
              field = :msgstr
              entries[key] = unescape(Regexp.last_match(1))
            when /\A"(.*)"\z/
              fragment = unescape(Regexp.last_match(1))
              case field
              when :msgid
                entries[key + fragment] = entries.delete(key).to_s
                key += fragment
              when :msgstr
                entries[key] += fragment
              end
            when "", /\A#/
              field = nil
            end
          end
          entries.reject { |msgid, msgstr| msgid.empty? || msgstr.empty? }
        end

        def unescape(text)
          text.gsub(/\\(.)/) do
            case Regexp.last_match(1)
            when "n" then "\n"
            when "t" then "\t"
            when "r" then "\r"
            else Regexp.last_match(1)
            end
          end
        end
    end
  end

  # Upstream writes `__ "Some string"`; the port writes `_("Some string")`,
  # which is what every other Ruby gettext-ish codebase writes.
  def self._(msgid) = Translation.tr(msgid)
end
