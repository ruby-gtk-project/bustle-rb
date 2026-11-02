# frozen_string_literal: true

require "set"

require "adwaita"

require_relative "marquee"
require_relative "translation"

module Bustle
  # Picks which services are drawn.
  #
  # Ported from upstream's Bustle/UI/FilterDialog.hs. Unticking a service
  # hides its column and every message it takes part in; the dialog returns
  # the set of unique names to hide, which the renderer takes as a filter.
  #
  # The name formatting is upstream's too: a connection owning several
  # well-known names in one namespace is listed as "org.example.{Foo,Bar}"
  # rather than as two full names, because the interesting part is the tail.
  class FilterDialog
    LIST_CSS_CLASS = "bustle-filter-names"

    # Upstream turns the tree view's rules hint on, with the comment "we want
    # rules because otherwise it's tough to see where each group starts and
    # ends" — a connection owning four well-known names is four lines in one
    # row, and without banding it is not clear where the next connection
    # begins. GTK4 has no rules hint, so the banding is said in CSS against a
    # class on the list, in the foreground colour at the alpha a theme's own
    # alternating rows use. The node name is `list`, not `listbox`: GTK4
    # renamed GtkListBox's CSS node and a GTK3-era selector silently matches
    # nothing.
    CSS = <<~CSS
      list.#{LIST_CSS_CLASS} > row:nth-child(even) {
        background-color: alpha(currentColor, 0.04);
      }
    CSS

    # Upstream's size requests: 600x371 on the name view and 600 wide on the
    # instructions, so the dialog opens wide enough to show a bus name in full
    # even when the parent window is narrow.
    NAME_VIEW_WIDTH = 600
    NAME_VIEW_HEIGHT = 371

    def initialize(participants:, hidden:, on_apply:)
      @participants = participants
      @hidden = hidden
      @on_apply = on_apply
      @rows = {}
    end

    def present(parent)
      FilterDialog.install_css
      window.tap do |dialog|
        dialog.transient_for = parent
        dialog.default_width = (parent.width * 7) / 8
        dialog.default_height = parent.height / 2
        dialog.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          header_bar.pack_end(close_button)

          content_box.tap do |box|
            box.append(instructions)
            box.append(scroller)

            scroller.child = list_box

            list_box.tap do |list|
              @participants.each { |unique_name, other_names| list.append(row_for(unique_name, other_names)) }
            end
          end
        end

        # Closing the window is what applies the filter, however it is
        # closed: upstream's dialog has the same single Close button.
        close_button.signal_connect("clicked") { dialog.close }
        dialog.signal_connect("close-request") do
          apply
          false
        end

        dialog.present
      end
    end

    def window
      @window ||= Adwaita::Window.new.tap do |dialog|
        dialog.title = Bustle._("Filter Visible Services")
        dialog.modal = true
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
      end
    end

    def close_button
      @close_button ||= Gtk::Button.new(label: Bustle._("_Close")).tap do |button|
        button.use_underline = true
        button.add_css_class("suggested-action")
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.margin_top = 12
        box.margin_bottom = 12
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def instructions
      @instructions ||= Gtk::Label.new(instructions_text).tap do |label|
        label.wrap = true
        label.xalign = 0
        label.set_size_request(NAME_VIEW_WIDTH, -1)
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |sw|
        sw.hexpand = true
        sw.vexpand = true
        sw.has_frame = true
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class("boxed-list")
        list.add_css_class(LIST_CSS_CLASS)
        list.set_size_request(NAME_VIEW_WIDTH, NAME_VIEW_HEIGHT)
      end
    end

    class << self
      # One provider for the whole display, added once however many dialogs
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

      # "org.example.{Foo,Bar}", one line per namespace, or the unique name
      # for a connection that never claimed a well-known one.
      def format_names(unique_name, other_names)
        if other_names.empty?
          unique_name.to_s
        else
          grouped(other_names).map { |prefix, tails| format_group(prefix, tails) }.join("\n")
        end
      end

      private

        def grouped(other_names)
          other_names.map(&:to_s).sort
                     .map { |name| namespace(name) }
                     .chunk_while { |one, other| one.first == other.first }
                     .map { |group| [group.first.first, group.map(&:last)] }
        end

        # Splits "org.example.Foo" after the last dot, which is where the
        # interesting part of a bus name starts.
        def namespace(name)
          name.rindex(".").then do |index|
            if index
              [name[0..index], name[(index + 1)..]]
            else
              ["", name]
            end
          end
        end

        def format_group(prefix, tails)
          if tails.length == 1
            "#{prefix}#{tails.first}"
          else
            "#{prefix}{#{tails.join(",")}}"
          end
        end
    end

    private

      def row_for(unique_name, other_names)
        Adwaita::ActionRow.new.tap do |row|
          row.title = Marquee.escape_markup(FilterDialog.format_names(unique_name, other_names))
          row.activatable_widget = check_for(unique_name)
          row.add_suffix(check_for(unique_name))
        end
      end

      def check_for(unique_name)
        @rows[unique_name] ||= Gtk::CheckButton.new.tap do |check|
          check.active = !@hidden.include?(unique_name)
          check.valign = :center
        end
      end

      def apply
        @on_apply.call(Set.new(@rows.reject { |_name, check| check.active? }.keys))
      end

      def instructions_text
        Bustle._(
          "Unticking a service hides its column in the diagram, and all " \
          "messages it is involved in. That is, all methods it calls or are " \
          "called on it, the corresponding returns, and all signals it emits " \
          "will be hidden.",
        )
      end
  end
end
