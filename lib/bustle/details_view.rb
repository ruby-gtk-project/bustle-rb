# frozen_string_literal: true

require "adwaita"

require_relative "marquee"
require_relative "translation"
require_relative "types"
require_relative "variant_formatter"

module Bustle
  # The pane below the diagram showing everything about the selected message.
  #
  # Ported from upstream's Bustle/UI/DetailsView.hs and the detailsGrid widget
  # in data/bustle.ui: the kind of message, who sent it, who it was for, the
  # object path, the member, and the arguments one per line with their
  # signatures.
  #
  # Two things changed in the port. Upstream's caption-and-value grid becomes
  # a list of Adwaita rows, which is how the rest of a GNOME app shows the
  # same shape. And upstream's GtkStack of five pre-translated kind names
  # becomes one row whose subtitle is set from the same five strings. The
  # destination row still disappears for a broadcast signal, which has no
  # destination to show.
  class DetailsView
    UNKNOWN = ""

    def build
      container.tap do |box|
        box.append(group)
        box.append(arguments_caption)
        box.append(arguments_scroller)

        group.tap do |rows|
          rows.add(type_row)
          rows.add(sender_row)
          rows.add(destination_row)
          rows.add(path_row)
          rows.add(member_row)
        end

        arguments_scroller.child = arguments_view
      end
    end

    def top = container

    # Fills the pane in for one message, or hides it when the selection is
    # cleared.
    def update(detailed)
      if detailed
        show_message(detailed)
      else
        container.visible = false
      end
    end

    def container
      @container ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 12
        box.margin_end = 12
        box.visible = false
      end
    end

    def group = @group ||= Adwaita::PreferencesGroup.new

    def type_row = @type_row ||= detail_row(Bustle._("Type"))

    def sender_row = @sender_row ||= detail_row(Bustle._("Sender"))

    def destination_row = @destination_row ||= detail_row(Bustle._("Destination"))

    def path_row = @path_row ||= detail_row(Bustle._("Path"))

    def member_row = @member_row ||= detail_row(Bustle._("Member"))

    # Upstream dims this caption exactly as it dims the five above it — the
    # grid's captions are all dim-label in data/bustle.ui — so it is a quiet
    # label and not a heading.
    def arguments_caption
      @arguments_caption ||= Gtk::Label.new(Bustle._("Arguments")).tap do |label|
        label.xalign = 0
        label.add_css_class("dim-label")
      end
    end

    def arguments_scroller
      @arguments_scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.hexpand = true
        sw.vexpand = true
        sw.height_request = 80
        sw.has_frame = true
      end
    end

    def arguments_view
      @arguments_view ||= Gtk::TextView.new.tap do |view|
        view.editable = false
        view.monospace = true
        view.left_margin = 6
        view.right_margin = 6
      end
    end

    private

      def show_message(detailed)
        member = member_of(detailed)
        type_row.subtitle = as_text(type_name(detailed))
        sender_row.subtitle = as_text(sender_of(detailed))
        show_destination(destination_of(detailed))
        path_row.subtitle = as_text(member&.path)
        member_row.subtitle = member_markup(member)
        arguments_view.buffer.text = format_arguments(detailed)
        container.visible = true
      end

      def show_destination(destination)
        destination_row.subtitle = as_text(destination)
        destination_row.visible = !destination.nil?
      end

      # Upstream draws this line deliberately: `labelSetText` for the sender,
      # the destination and the path, `labelSetMarkup` only for the member,
      # which is the one value it marks up itself. An AdwActionRow subtitle is
      # markup whatever is put in it, so the four plain values are escaped on
      # the way in rather than left to be reinterpreted.
      def as_text(value) = Marquee.escape_markup(value.to_s)

      def type_name(detailed)
        case detailed.event
        when Types::MethodCall then Bustle._("Method call")
        when Types::MethodReturn then Bustle._("Method return")
        when Types::ErrorReturn then Bustle._("Error")
        when Types::Signal then signal_type_name(detailed.event)
        end
      end

      def sender_of(detailed)
        if detailed.message?
          detailed.event.sender
        end
      end

      def signal_type_name(signal)
        if signal.signal_destination
          Bustle._("Directed signal")
        else
          Bustle._("Signal")
        end
      end

      # A return or an error has no member of its own, so it borrows the one
      # from the call it answers — which is also how the diagram labels it.
      def member_of(detailed)
        case detailed.event
        when Types::MethodCall, Types::Signal then detailed.event.member
        when Types::MethodReturn, Types::ErrorReturn then detailed.event.in_reply_to&.event&.member
        end
      end

      # A broadcast signal has no destination, and neither has a name-owner
      # change — which the canvas never selects, but which can arrive here
      # from a caller holding any event at all.
      def destination_of(detailed)
        case detailed.event
        when Types::Signal then detailed.event.signal_destination
        when Types::MethodCall, Types::MethodReturn, Types::ErrorReturn then detailed.event.destination
        end
      end

      def member_markup(member)
        if member
          Marquee.format_member(member.interface, member.member_name).to_markup
        else
          UNKNOWN
        end
      end

      def format_arguments(detailed)
        detailed.body.map { |argument| VariantFormatter.format_variant(VariantFormatter::SIGNATURE, argument) }
                .join("\n")
      end

      # The values are selectable, because the first thing anyone does with a
      # bus name or an object path is copy it somewhere else.
      def detail_row(title)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.subtitle = UNKNOWN
          row.subtitle_selectable = true
          row.add_css_class("property")
        end
      end
  end
end
