# frozen_string_literal: true

require "fileutils"
require "set"

require "adwaita"

require_relative "about_dialog"
require_relative "canvas"
require_relative "details_view"
require_relative "error_bar"
require_relative "filter_dialog"
require_relative "header_bar"
require_relative "loader"
require_relative "menus"
require_relative "open_dialog"
require_relative "open_two_dialog"
require_relative "pdf_export"
require_relative "monitor"
require_relative "please_hold_page"
require_relative "record_address_dialog"
require_relative "recorder"
require_relative "renderer"
require_relative "statistics_pane"
require_relative "translation"
require_relative "util"
require_relative "welcome_page"

module Bustle
  # One window: a log, the diagram drawn from it, and everything that acts on
  # them.
  #
  # Ported from upstream's Bustle/UI.hs and the diagramWindow widget in
  # data/bustle.ui. The shape is upstream's: a stack showing either the
  # welcome page, the "please hold" page or the diagram; a statistics sidebar
  # that slides in beside it; the diagram above a details pane; and an error
  # bar across the top for whatever would not load.
  #
  # Upstream opens one window per log and quits when the last one closes,
  # which is why loading a log is a method on the window rather than on the
  # application: a window with nothing in it is the one that gets re-used.
  class Window
    INSTRUCTIONS_PAGE = "instructions"
    PLEASE_HOLD_PAGE = "please-hold"
    CANVAS_PAGE = "canvas"

    DEFAULT_WIDTH = 900
    DEFAULT_HEIGHT = 700
    DETAILS_POSITION = 400

    # Which log, or pair of logs, this window is showing. A recorded log is
    # the one case that is not yet saved anywhere permanent, which is why
    # upstream distinguishes it.
    LogDetails = Data.define(:kind, :paths) do
      class << self
        def single(path) = new(kind: :single, paths: [path])

        def two(session_path, system_path) = new(kind: :two, paths: [session_path, system_path])

        def recorded(path) = new(kind: :recorded, paths: [path])
      end

      def session_path = paths.first

      def system_path = paths.last

      # Upstream's logWindowTitle: the filename as the title, its directory as
      # the subtitle, and an asterisk on a recording that has not been saved.
      def title_pair
        case kind
        when :recorded then ["*#{File.basename(session_path)}", ""]
        when :single then [File.basename(session_path), File.dirname(session_path)]
        else two_log_title_pair
        end
      end

      # Upstream's logTitle, which is also the name suggested for a PDF.
      def log_title = paths.map { |path| File.basename(path, ".*") }.join(" & ")

      # Where a PDF should be saved by default; a recording has no meaningful
      # directory yet.
      def directory
        case kind
        when :recorded then nil
        else File.dirname(session_path)
        end
      end

      private

        def two_log_title_pair
          directories = paths.map { |path| File.dirname(path) }
          names = paths.map { |path| File.basename(path) }
          [names.join(" & "), directories.uniq.join(" & ")]
        end
    end

    # `windows` is the Application, which keeps track of which window is the
    # initial empty one; upstream holds that in its BState. A window built
    # without one acts on itself, which is what a single window wants.
    def initialize(app:, show_bounds: false, windows: nil)
      @app = app
      @show_bounds = show_bounds
      @windows = windows
      @recorder = nil
      @hidden = Set.new
      @details = nil
      @session_messages = []
      @system_messages = []
      @result = Renderer::Result.empty
    end

    def build
      window.tap do |win|
        win.child = toolbar_view

        win.signal_connect("close-request") { prompt_to_save }

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar.build)
          view.content = content_box

          content_box.tap do |box|
            box.append(error_bar.build)
            box.append(stack)

            stack.tap do |pages|
              pages.add_named(welcome_page.build, INSTRUCTIONS_PAGE)
              pages.add_named(please_hold_page.build, PLEASE_HOLD_PAGE)
              pages.add_named(sidebar_paned, CANVAS_PAGE)

              sidebar_paned.tap do |split|
                split.start_child = sidebar_toolbar
                split.end_child = diagram_paned

                sidebar_toolbar.tap do |sidebar|
                  sidebar.add_top_bar(header_bar.build_sidebar_header(statistics_pane.stack))
                  sidebar.content = statistics_pane.build

                  sidebar_size_group.tap do |group|
                    group.add_widget(header_bar.sidebar_header)
                    group.add_widget(statistics_pane.stack)
                  end
                end

                diagram_paned.tap do |panes|
                  panes.start_child = canvas.build
                  panes.end_child = details_view.build
                end
              end
            end
          end
        end

        menus.install

        header_bar.stop_button.signal_connect("clicked") { @recorder&.stop }
      end
    end

    def present = window.present

    # Loads one log, or a session/system pair, and draws it. A log that will
    # not load leaves the window as it was, with the error bar explaining why
    # — which is how upstream's initial window survives a bad command line.
    def load(details)
      session_warnings, @session_messages = read(details.session_path)
      system_warnings, @system_messages = read_second(details)
      @hidden = Set.new
      @result = Renderer.process(@session_messages, @system_messages)
      report(session_warnings + system_warnings + @result.warnings)
      display(details)
      error_bar.hide
    rescue Loader::LoadError => e
      error_bar.show(format(Bustle._("Could not read '%s'"), e.path), e.message)
      @windows&.put_initial_window(self)
    end

    # True while this window has nothing in it, which is what makes it the
    # one an Open or a Record loads into.
    def empty? = @details.nil?

    # Upstream's startRecording: begins recording `target` — the session bus,
    # the system bus, or an address — into a temporary file, and shows the
    # diagram growing as it goes.
    def begin_recording(target)
      recorder_for(target).tap do |recording|
        error_bar.hide
        header_bar.start_recording(recording.title)
        show_waiting
        present
        recording.start
      end
    end

    # The page a running recording shows until the first message arrives.
    def show_waiting
      stack.visible_child_name = PLEASE_HOLD_PAGE
    end

    # Gtk::ApplicationWindow with an Adwaita::ToolbarView inside it, as the
    # house skill requires: Adwaita::ApplicationWindow is broken in the Ruby
    # bindings. The toolbar view supplies the header bar, so the window is
    # told nothing about titlebars. See FINDINGS.md.
    def window
      @window ||= Gtk::ApplicationWindow.new(@app).tap do |win|
        win.title = Bustle._("Bustle")
        win.icon_name = AboutDialog::LOGO_ICON_NAME
        win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def stack
      @stack ||= Gtk::Stack.new.tap do |pages|
        pages.vexpand = true
        pages.visible_child_name = INSTRUCTIONS_PAGE
      end
    end

    # The statistics sidebar starts hidden, as upstream's does; the
    # Statistics action reveals it. Its width is not set here: upstream ties
    # sidebarHeader and sidebarStack together with a GtkSizeGroup and lets the
    # tables decide how wide the sidebar is.
    def sidebar_toolbar
      @sidebar_toolbar ||= Adwaita::ToolbarView.new.tap do |sidebar|
        sidebar.visible = false
      end
    end

    # Upstream's unnamed GtkSizeGroup over sidebarHeader and sidebarStack
    # (data/bustle.ui:919), which keeps the sidebar's title bar exactly as
    # wide as the statistics tables below it.
    def sidebar_size_group = @sidebar_size_group ||= Gtk::SizeGroup.new(:horizontal)

    def sidebar_paned
      @sidebar_paned ||= Gtk::Paned.new(:horizontal).tap do |split|
        split.resize_start_child = false
        split.shrink_start_child = false
      end
    end

    def diagram_paned
      @diagram_paned ||= Gtk::Paned.new(:vertical).tap do |panes|
        panes.position = DETAILS_POSITION
        panes.shrink_end_child = false
      end
    end

    def header_bar = @header_bar ||= HeaderBar.new(menus:)

    def error_bar = @error_bar ||= ErrorBar.new

    def welcome_page = @welcome_page ||= WelcomePage.new

    def please_hold_page = @please_hold_page ||= PleaseHoldPage.new

    def statistics_pane = @statistics_pane ||= StatisticsPane.new

    def details_view = @details_view ||= DetailsView.new

    def canvas
      @canvas ||= Canvas.new(show_bounds: @show_bounds, on_selection_changed: method(:on_selection_changed))
    end

    def menus
      @menus ||= Menus.new(app: @app, window:, handlers: action_handlers)
    end

    private

      def action_handlers
        {
          "open"                   => method(:action_open),
          "open-pair"              => method(:action_open_pair),
          "record-session"         => method(:action_record_session),
          "record-system"          => method(:action_record_system),
          "record-address"         => method(:action_record_address),
          Menus::SAVE_ACTION       => method(:action_save),
          "filter"                 => method(:action_filter),
          "export-pdf"             => method(:action_export_pdf),
          "about"                  => method(:action_about),
          Menus::STATISTICS_ACTION => method(:show_statistics),
        }
      end

      # Upstream loads into the initial window — the empty one a fresh app
      # opened, or the one whose command-line log would not load — rather
      # than into whichever window asked.
      def action_open
        OpenDialog.new(on_chosen: ->(path) { load_in_initial_window(LogDetails.single(path)) }).present(window)
      end

      def action_open_pair
        OpenTwoDialog.new(
          on_open: lambda { |session_path, system_path|
            load_in_initial_window(LogDetails.two(session_path, system_path))
          },
        ).present(window)
      end

      def load_in_initial_window(details)
        initial_window.tap do |target|
          target.load(details)
          target.present
        end
      end

      def initial_window = @windows&.consume_initial_window || self

      def action_record_session = initial_window.begin_recording(Monitor::SESSION_BUS)

      def action_record_system = initial_window.begin_recording(Monitor::SYSTEM_BUS)

      def action_record_address
        RecordAddressDialog.new(
          on_record: ->(address) { initial_window.begin_recording(Monitor.target_for(address)) },
        ).present(window)
      end

      def recorder_for(target)
        @recorder = Recorder.new(
          target:      target,
          on_progress: method(:recording_progress),
          on_finished: method(:recording_finished),
          on_error:    ->(message) { error_bar.show(message) },
        )
      end

      # Upstream's aChallengerAppears: redraw with everything rendered so
      # far, follow the bottom of the diagram, and count the messages.
      def recording_progress(count, result)
        @result = result
        header_bar.set_message_count(count)
        show_result(result)
        canvas.scroll_to_bottom
        stack.visible_child_name = CANVAS_PAGE
      end

      # Upstream's finishedRecording. A recording that produced something is
      # re-read off the temporary file so the statistics, the filter and the
      # export all see a finished log; one that produced nothing leaves the
      # window as empty as it found it.
      def recording_finished(path, produced_output)
        @recorder = nil
        header_bar.finish_recording
        if produced_output
          load(LogDetails.recorded(path))
          menus.set_enabled(Menus::SAVE_ACTION, true)
        else
          abandon_recording
        end
      end

      def abandon_recording
        @details = nil
        @result = Renderer::Result.empty
        show_result(@result)
        header_bar.clear_title
        stack.visible_child_name = INSTRUCTIONS_PAGE
        @windows&.put_initial_window(self)
      end

      # Upstream's showSaveDialog: move the temporary file where the user
      # asked, and from then on this is an ordinary saved log.
      def action_save = show_save_dialog

      def show_save_dialog(&saved)
        @details.session_path.then do |temporary|
          Recorder.choose_file(name: File.basename(temporary), parent: window) do |chosen|
            save_recording(temporary, chosen, &saved)
          end
        end
      end

      def save_recording(temporary, chosen, &saved)
        FileUtils.mv(temporary, chosen)
        menus.set_enabled(Menus::SAVE_ACTION, false)
        set_details(LogDetails.single(chosen))
        error_bar.hide
        saved&.call
      rescue SystemCallError, IOError => e
        error_bar.show("#{Bustle._("Couldn't save log: ")}#{e.message}", recovery_advice(temporary))
      end

      def recovery_advice(temporary)
        format(
          Bustle._("You might want to manually recover the log from the temporary file at \"%s\"."),
          temporary,
        )
      end

      # Upstream's promptToSave, which GTK3 hangs off delete-event; GTK4 calls
      # it close-request, where returning true means "do not close yet".
      def prompt_to_save
        if @details&.kind == :recorded
          save_prompt.tap { |dialog| dialog.heading = save_prompt_heading }.present(window)
          true
        else
          false
        end
      end

      def save_prompt_heading
        format(Bustle._("Save log '%s' before closing?"), File.basename(@details.session_path))
      end

      def save_prompt
        @save_prompt ||= Adwaita::AlertDialog.new(
          "",
          Bustle._("If you don't save, this log will be lost forever."),
        ).tap do |dialog|
          dialog.add_response("close", Bustle._("Close _Without Saving"))
          dialog.add_response("cancel", Bustle._("_Cancel"))
          dialog.add_response("save", Bustle._("Save"))
          dialog.set_response_appearance("close", :destructive)
          dialog.set_response_appearance("save", :suggested)
          dialog.default_response = "save"
          dialog.close_response = "cancel"
          dialog.signal_connect("response") { |_dialog, response| answer_save_prompt(response) }
        end
      end

      def answer_save_prompt(response)
        case response
        when "save" then show_save_dialog { window.destroy }
        when "close" then window.destroy
        end
      end

      # Re-renders with the chosen services hidden. Upstream re-runs the whole
      # renderer too: filtering is a property of the layout, not of the
      # drawing, because hiding a column moves everything to its right.
      def action_filter
        FilterDialog.new(
          participants: @result.applications.session_participants,
          hidden:       @hidden,
          on_apply:     method(:apply_filter),
        ).present(window)
      end

      def apply_filter(hidden)
        @hidden = hidden
        show_result(Renderer.process_with_filters([@session_messages, hidden], [@system_messages, Set.new]))
      end

      def action_export_pdf
        PdfExport.new(
          shapes:         canvas.shapes,
          suggested_name: @details&.log_title.to_s,
          directory:      @details&.directory,
          on_error:       ->(message) { error_bar.show(message) },
          on_success:     ->(_path) { error_bar.hide },
        ).present(window)
      end

      def action_about = AboutDialog.new.present(window)

      def show_statistics(showing)
        sidebar_toolbar.visible = showing
      end

      def on_selection_changed(message)
        details_view.update(message)
      end

      def read(path) = Loader.read_log(path)

      # A single log leaves the system bus side empty; a pair fills both.
      def read_second(details)
        case details.kind
        when :two then read(details.system_path)
        else [[], []]
        end
      end

      def report(warnings)
        warnings.each { |warning| Util.warn(warning) }
      end

      def set_details(details)
        @details = details
        set_titles(details)
      end

      def display(details)
        @details = details
        set_titles(details)
        show_result(@result)
        statistics_pane.set_messages(@session_messages, @system_messages)
        Menus::NEEDS_LOG.each { |name| menus.set_enabled(name, true) }
        stack.visible_child_name = CANVAS_PAGE
        canvas.focus
      end

      def set_titles(details)
        title, subtitle = details.title_pair
        window.title = title
        header_bar.set_title(title, subtitle)
      end

      def show_result(result)
        canvas.set_shapes(
          result.shapes,
          result.regions,
          result.centre_offset,
          visible_width,
        )
      end

      # A log can be loaded from the command line before the window has been
      # mapped, when its allocated width is still zero; the default size is
      # the best guess available for centring the timestamp column.
      def visible_width
        window.width.then do |width|
          if width.zero?
            DEFAULT_WIDTH
          else
            width
          end
        end
      end
  end
end
