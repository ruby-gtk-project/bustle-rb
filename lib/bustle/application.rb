# frozen_string_literal: true

require "adwaita"

require_relative "translation"
require_relative "window"

module Bustle
  # The application: one window per log named on the command line, or one
  # empty window if none were.
  #
  # Ported from upstream's uiMain and mainB in Bustle/UI.hs. Upstream counts
  # its windows itself and calls mainGUI/mainQuit around them; a
  # GtkApplication does that counting, so what is left here is upstream's
  # argument handling — a list of logs opens one window each, --pair opens one
  # window with both, and --debug draws every shape's bounding box.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "org.rubygtkproject.Bustle"

    # Upstream installs data/icons into the prefix and leaves the rest to the
    # icon theme. A copy run out of its own source tree — which is how the
    # drive scripts and `ruby exe/bustle` run it — is not installed anywhere,
    # so the theme has to be pointed at the icons the port ships, or the
    # welcome page and the about dialog draw a broken-image placeholder where
    # the logo should be.
    ICON_DIRECTORY = File.expand_path("../../data/icons", __dir__)

    def initialize(logs: [], pair: nil, show_bounds: false, app_id: APP_ID, flags: :default_flags, present: true)
      @logs = logs
      @pair = pair
      @show_bounds = show_bounds
      @app_id = app_id
      @flags = flags
      @present = present
    end

    def build
      app.tap do
        app.signal_connect("activate") do
          install_icons
          targets.each { |details| open_window(details) }
        end
      end
    end

    def run = app.run([])

    # Adwaita has to be initialised before any of its widgets are built, and
    # Adwaita::Application is broken in the bindings, so the application
    # object is a Gtk one that initialises Adwaita by hand.
    def app
      @app ||= begin
        Adwaita.init
        Gtk::Application.new(@app_id, @flags)
      end
    end

    # The windows this run has opened, in the order they were opened.
    def windows = @windows ||= []

    # Upstream's consumeInitialWindow: the window an Open or a Record should
    # load into. A fresh app opens one empty window and remembers it here; a
    # command line whose log would not load leaves that window remembered too,
    # so the error bar stays visible until something replaces it. Once it has
    # been used it is forgotten, and the next Open gets a window of its own.
    def consume_initial_window
      @initial_window.then do |remembered|
        @initial_window = nil
        if remembered&.empty?
          remembered
        else
          open_window(nil)
        end
      end
    end

    # Upstream's putInitialWindow.
    def put_initial_window(window)
      @initial_window = window
    end

    private

      # The display only exists once the application has activated, which is
      # why this is not in `app`.
      def install_icons
        Gdk::Display.default.then do |display|
          if display && File.directory?(ICON_DIRECTORY)
            Gtk::IconTheme.get_for_display(display).add_search_path(ICON_DIRECTORY)
          end
        end
      end

      # One window per log named on the command line, or one window with
      # nothing in it — which is the window the Open action then loads into.
      def targets
        if @pair
          [Window::LogDetails.two(@pair.first, @pair.last)]
        elsif @logs.empty?
          [nil]
        else
          @logs.map { |path| Window::LogDetails.single(path) }
        end
      end

      def open_window(details)
        Window.new(app:, show_bounds: @show_bounds, windows: self).tap do |window|
          window.build
          if details
            window.load(details)
          else
            put_initial_window(window)
          end
          if @present
            window.present
          end
          windows << window
        end
      end
  end
end
