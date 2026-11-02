# frozen_string_literal: true

require "adwaita"

require_relative "open_dialog"
require_relative "translation"

module Bustle
  # Opens a session bus log and a system bus log together, to be drawn side
  # by side in one diagram.
  #
  # Ported from upstream's Bustle/UI/OpenTwoDialog.hs and data/OpenTwoDialog.ui.
  # GTK4 removed GtkFileChooserButton, so each row here opens a GtkFileDialog
  # of its own; what survives is the behaviour around them. Open stays
  # insensitive until both logs have been chosen, and choosing a session log
  # moves the system log chooser to the same folder — but only while that
  # chooser is still empty, so picking the second file from elsewhere cannot
  # unpick the first, which is the condition upstream's
  # propagateCurrentFolder tests.
  #
  # Upstream propagates on `current-folder-changed`, so merely browsing in one
  # chooser moves the other even before a file is picked. GtkFileDialog is a
  # one-shot dialog with no signals at all — GTK4 dropped every signal from
  # GtkFileChooser — so browsing cannot be observed, and the folder can only
  # travel when a file is actually chosen.
  class OpenTwoDialog
    def initialize(on_open:)
      @on_open = on_open
      @chosen = {}
    end

    def present(parent)
      window.tap do |dialog|
        dialog.transient_for = parent
        dialog.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          header_bar.tap do |bar|
            bar.pack_start(cancel_button)
            bar.pack_end(open_button)
          end

          content_box.tap do |box|
            box.append(group)

            group.tap do |rows|
              rows.add(session_row)
              rows.add(system_row)

              session_row.add_suffix(session_button)
              system_row.add_suffix(system_button)
            end
          end
        end

        session_button.signal_connect("clicked") { choose(:session) }
        system_button.signal_connect("clicked") { choose(:system) }
        cancel_button.signal_connect("clicked") { dialog.close }
        open_button.signal_connect("clicked") { open_both }

        update_sensitivity
        dialog.present
      end
    end

    def window
      @window ||= Adwaita::Window.new.tap do |dialog|
        dialog.title = Bustle._("Open a Pair of Logs")
        dialog.modal = true
        dialog.default_width = 480
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
        bar.show_start_title_buttons = false
      end
    end

    def cancel_button = @cancel_button ||= Gtk::Button.new(label: Bustle._("_Cancel")).tap { |b| b.use_underline = true }

    def open_button
      @open_button ||= Gtk::Button.new(label: Bustle._("_Open")).tap do |button|
        button.use_underline = true
        button.add_css_class("suggested-action")
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.margin_top = 12
        box.margin_bottom = 12
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap do |rows|
        rows.description = Bustle._(
          "Display two logs—one for the session bus, one for the system bus—side by side.",
        )
      end
    end

    def session_row = @session_row ||= log_row(Bustle._("Session bus log:"))

    def system_row = @system_row ||= log_row(Bustle._("System bus log:"))

    def session_button = @session_button ||= choose_button

    def system_button = @system_button ||= choose_button

    private

      def choose(which)
        file_dialog(which).open(window, nil) do |_source, result|
          chosen(which, file_dialog(which).open_finish(result).path)
        rescue GLib::Error
          # Dismissed; the row keeps whatever it already had.
          nil
        end
      end

      def chosen(which, path)
        @chosen[which] = path
        row_for(which).subtitle = path
        propagate_folder(which, path)
        update_sensitivity
      end

      # The other chooser starts in this file's folder, as long as it has not
      # had a file chosen in it already.
      def propagate_folder(which, path)
        other = other_than(which)
        unless @chosen[other]
          file_dialog(other).initial_folder = Gio::File.new_for_path(File.dirname(path))
        end
      end

      def other_than(which)
        case which
        when :session then :system
        else :session
        end
      end

      def row_for(which)
        case which
        when :session then session_row
        else system_row
        end
      end

      def file_dialog(which)
        @file_dialogs ||= {}
        @file_dialogs[which] ||= Gtk::FileDialog.new.tap do |chooser|
          chooser.title = chooser_title(which)
          chooser.modal = true
          chooser.filters = OpenDialog.filters
        end
      end

      def chooser_title(which)
        case which
        when :session then Bustle._("Select session bus log")
        else Bustle._("Select system bus log")
        end
      end

      def update_sensitivity
        open_button.sensitive = !@chosen[:session].nil? && !@chosen[:system].nil?
      end

      def open_both
        @on_open.call(@chosen[:session], @chosen[:system])
        window.close
      end

      def log_row(title)
        Adwaita::ActionRow.new.tap do |row|
          row.title = title
          row.subtitle = Bustle._("(none chosen)")
        end
      end

      def choose_button
        Gtk::Button.new(label: Bustle._("Choose…")).tap do |button|
          button.valign = :center
        end
      end
  end
end
