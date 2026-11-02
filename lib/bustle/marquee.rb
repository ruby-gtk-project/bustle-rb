# frozen_string_literal: true

require_relative "translation"

module Bustle
  # A tiny type-safe Pango markup builder.
  #
  # Ported from upstream's Bustle/Marquee.hs, whose cutesy name exists so it
  # does not collide with Pango's own "Markup", which is just a String. The
  # point of the type is that the only way to get text into a Marquee is
  # through `escape`, so a member name containing "&" or "<" cannot break the
  # markup it lands in. Marquees concatenate with `+`, and the widgets ask for
  # `to_markup` (for a label) or `to_s` (for the plain text behind it).
  class Marquee
    class << self
      def empty = new("")

      def escape(text) = new(escape_markup(stringify(text)))

      def tag(name, contents) = new("<#{name}>#{contents.to_markup}</#{name}>")

      def b(contents) = tag("b", contents)

      def i(contents) = tag("i", contents)

      def small(contents) = tag("small", contents)

      def light(contents) = span({"font_weight" => "light"}, contents)

      def red(contents) = span({"foreground" => "#ff0000"}, contents)

      def a(href, contents)
        new(%(<a href="#{escape_markup(href)}">#{escape_markup(contents)}</a>))
      end

      def span(attributes, contents)
        attributes.map { |name, value| %( #{name}="#{escape_markup(value)}") }
                  .join
                  .then { |rendered| new("<span#{rendered}>#{contents.to_markup}</span>") }
      end

      def concat(marquees) = new(marquees.map(&:to_markup).join)

      # "org.example.Iface.Method", with the member in bold — and a dimmed
      # apology where the interface should be for the messages that omit it.
      def format_member(interface, member)
        if interface
          escape(interface) + new(".") + b(escape(member))
        else
          light(escape("(no interface) ")) + b(escape(member))
        end
      end

      def escape_markup(text)
        stringify(text).gsub("&", "&amp;")
                       .gsub("<", "&lt;")
                       .gsub(">", "&gt;")
                       .gsub("'", "&apos;")
                       .gsub('"', "&quot;")
      end

      private

        def stringify(value) = value.to_s
    end

    def initialize(markup)
      @markup = markup
    end

    def to_markup = @markup

    # The markup with its tags and entities taken back out: the error bar's
    # title goes through this on the way to a plain-text dialog.
    def to_s
      @markup.gsub(%r{</?[^>]+>}, "")
             .gsub("&lt;", "<")
             .gsub("&gt;", ">")
             .gsub("&apos;", "'")
             .gsub("&quot;", '"')
             .gsub("&amp;", "&")
    end

    def +(other) = Marquee.new(@markup + other.to_markup)

    def ==(other) = other.is_a?(Marquee) && other.to_markup == @markup

    alias_method :eql?, :==

    def hash = @markup.hash

    def empty? = @markup.empty?
  end
end
