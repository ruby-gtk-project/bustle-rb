# frozen_string_literal: true

require "adwaita"

require_relative "open_dialog"
require_relative "translation"

module Bustle
  # Opens a session bus log and a system bus log together, to be drawn side
  # by side in one diagram.
  #
  # Ported from upstream's Bustle/UI/OpenTwoDialog.hs and data/OpenTwoDialog.ui.
  # GTK4 removed GtkFileChooserButton, so each row here opens a
  # Gtk::FileDialog of its own in place of upstream's embedded chooser.
  #
  # I have not reproduced one behaviour of upstream's. Its
  # propagateCurrentFolder (OpenTwoDialog.hs:36-44) connects
  # `current-folder-changed` on each chooser, so browsing to a folder in one
  # of them — before any file is picked, just by navigating — moves the other
  # chooser to that folder as long as it is still empty. Here the folder
  # travels only when a file has actually been chosen, so a user who browses
  # to ~/logs in the session chooser and then dismisses it still finds the
  # system chooser where it started. The folder a chosen file came from is
  # remembered for both choosers, which recovers the common case; it is not
  # the same thing, and FINDINGS.md says why the rest is expensive.
  #
  # What is reproduced is the guard upstream's comment is about: the folder
  # moves only while the other chooser is still empty, so picking the second
  # log from somewhere else cannot unpick the first. Open stays insensitive
  # until both logs have been chosen, as upstream's updateOpenSensitivity
  # makes it.
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
        remember_folder(which, File.dirname(path))
        update_sensitivity
      end

      # The folder a log came from is where both choosers should open next:
      # this one because that is where its user was last, and the other one
      # because that is upstream's propagation — but only while the other is
      # still empty, so a second log chosen elsewhere cannot drag the first
      # chooser away from the file it is showing.
      def remember_folder(which, folder)
        Gio::File.new_for_path(folder).then do |location|
          file_dialog(which).initial_folder = location
          other_than(which).then do |other|
            unless @chosen[other]
              file_dialog(other).initial_folder = location
            end
          end
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
