# frozen_string_literal: true

require "adwaita"

require_relative "translation"

module Bustle
  # The window's menus, actions and keyboard shortcuts.
  #
  # Ported from upstream's recordMenu, openMenu and filterStatsEtc menus in
  # data/bustle.ui, together with the signal connections Bustle/UI.hs makes to
  # their items. Upstream wires GtkMenuItems straight to callbacks and notes
  # in a comment that the drop-downs would look better as popovers and really
  # want to be GActions; this port is that rewrite — Gio menu models, window
  # actions, and the accelerators the port's shortcuts advertise.
  #
  # Statistics is a stateful action because the sidebar toggles, which is what
  # upstream's GtkCheckMenuItem was for.
  class Menus
    # action name => accelerators, as upstream's menu items advertise them.
    WINDOW_ACTIONS = {
      "open"       => ["<Control>o"],
      "open-pair"  => [],
      "filter"     => ["<Control>f"],
      "export-pdf" => ["<Control>s"],
      "about"      => [],
    }.freeze

    STATISTICS_ACTION = "statistics"
    STATISTICS_ACCELS = ["F9"].freeze

    # The actions that need a log open before they mean anything.
    NEEDS_LOG = [STATISTICS_ACTION, "filter", "export-pdf"].freeze

    def initialize(app:, window:, handlers:)
      @app = app
      @window = window
      @handlers = handlers
      @actions = {}
    end

    def install
      WINDOW_ACTIONS.each { |name, accels| add_action(name, accels) }
      add_statistics_action
      NEEDS_LOG.each { |name| set_enabled(name, false) }
      self
    end

    def set_enabled(name, enabled)
      @actions[name]&.enabled = enabled
    end

    def statistics_active? = @actions[STATISTICS_ACTION]&.state&.value == true

    def open_menu
      @open_menu ||= Gio::Menu.new.tap do |menu|
        menu.append(Bustle._("_Open…"), "win.open")
        menu.append(Bustle._("O_pen a Pair of Logs…"), "win.open-pair")
      end
    end

    def main_menu
      @main_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(
          nil,
          Gio::Menu.new.tap do |section|
            section.append(Bustle._("_Filter Visible Services…"), "win.filter")
            section.append(Bustle._("_Statistics"), "win.#{STATISTICS_ACTION}")
          end,
        )

        menu.append_section(
          nil,
          Gio::Menu.new.tap do |section|
            section.append(Bustle._("_About Bustle"), "win.about")
          end,
        )
      end
    end

    private

      def add_action(name, accels)
        Gio::SimpleAction.new(name, nil).tap do |action|
          action.signal_connect("activate") { @handlers.fetch(name).call }
          @window.add_action(action)
          @actions[name] = action
          unless accels.empty?
            @app.set_accels_for_action("win.#{name}", accels)
          end
        end
      end

      # A boolean action, so the menu item draws its own tick and the sidebar
      # can be toggled from the keyboard.
      def add_statistics_action
        Gio::SimpleAction.new(STATISTICS_ACTION, nil, GLib::Variant.new(false)).tap do |action|
          action.signal_connect("activate") { toggle_statistics(action) }
          @window.add_action(action)
          @actions[STATISTICS_ACTION] = action
          @app.set_accels_for_action("win.#{STATISTICS_ACTION}", STATISTICS_ACCELS)
        end
      end

      # ruby-gnome unwraps a variant through #value, so the action's state
      # arrives as a plain true or false.
      def toggle_statistics(action)
        (action.state.value != true).then do |showing|
          action.set_state(GLib::Variant.new(showing))
          @handlers.fetch(STATISTICS_ACTION).call(showing)
        end
      end
  end
end
