# frozen_string_literal: true

# Opens a log and drives the main window: the error bar, the canvas scroll
# step, the filter dialog, the open-a-pair dialog, the statistics sidebar and
# the details pane. Run it with
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "set"
require "tmpdir"

require_relative "gtk_driver"

require "bustle/application"
require "bustle/diagram"
require "bustle/filter_dialog"
require "bustle/open_two_dialog"
require "bustle/types"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir

LOG = File.expand_path("../spec/fixtures/log-with-h.bustle", __dir__)

application = Bustle::Application.new(logs: [LOG], app_id: "org.rubygtkproject.Bustle.Drive")
filter = nil
open_two = nil

GtkDriver.drive(application, shots: ENV.fetch("BUSTLE_SHOTS", File.join(Dir.tmpdir, "bustle-shots"))) do |d, app|
  d.window { app.windows.first.window }

  d.step("the log loads") do
    d.check("one window") { app.windows.length == 1 }
    d.check("canvas has shapes") { !app.windows.first.canvas.shapes.empty? }
    d.shot("01-diagram")
  end

  d.step("the canvas steps by one message row") do
    window = app.windows.first
    d.check("horizontal step is one event row") do
      window.canvas.scroller.hadjustment.step_increment == Bustle::Diagram::EVENT_HEIGHT
    end
    d.check("vertical step is one event row") do
      window.canvas.scroller.vadjustment.step_increment == Bustle::Diagram::EVENT_HEIGHT
    end
  end

  d.step("the error bar shows a title and details") do
    app.windows.first.error_bar.show("Could not read '/no/such/log'", "No such file or directory")
  end

  d.step("the error bar is error-coloured and selectable") do
    bar = app.windows.first.error_bar
    d.check("visible") { bar.container.visible? }
    d.check("error css class") { bar.container.css_classes.include?(Bustle::ErrorBar::CSS_CLASS) }
    d.check("title selectable") { bar.title_label.selectable? }
    d.check("details selectable") { bar.details_label.selectable? }
    d.check("details shown") { bar.details_label.visible? }
    d.check("close button carries an icon, not a label") do
      bar.close_button.icon_name == "window-close-symbolic" && bar.close_button.label.nil?
    end
    d.shot("02-error-bar")
  end

  d.step("the close button hides it") do
    app.windows.first.error_bar.close_button.activate
  end

  d.step("hidden") do
    d.check("not visible") { !app.windows.first.error_bar.container.visible? }
  end

  d.step("the filter dialog opens") do
    participants = [
      [Bustle::Types.unique_name(":1.1"), Set.new([Bustle::Types.other_name("org.example.Foo")])],
      [Bustle::Types.unique_name(":1.2"), Set.new([Bustle::Types.other_name("org.example.Bar")])],
      [Bustle::Types.unique_name(":1.3"), Set.new],
    ]
    filter = Bustle::FilterDialog.new(participants:, hidden: Set.new, on_apply: ->(_hidden) {})
    filter.present(app.windows.first.window)
  end

  d.step("the filter list is banded and sized as upstream's is") do
    d.check("dialog visible") { filter.window.visible? }
    d.check("banding class") { filter.list_box.css_classes.include?(Bustle::FilterDialog::LIST_CSS_CLASS) }
    d.check("name view 600x371") do
      filter.list_box.size_request == [Bustle::FilterDialog::NAME_VIEW_WIDTH, Bustle::FilterDialog::NAME_VIEW_HEIGHT]
    end
    d.check("instructions 600 wide") { filter.instructions.size_request == [Bustle::FilterDialog::NAME_VIEW_WIDTH, -1] }
    d.check("three rows") { filter.list_box.children.length == 3 }
    d.shot("03-filter", filter.window)
  end

  d.step("close the dialog") { filter.window.close }

  d.step("the open-a-pair dialog opens") do
    open_two = Bustle::OpenTwoDialog.new(on_open: ->(_session, _system) {})
    open_two.present(app.windows.first.window)
  end

  d.step("it asks for two logs and Open is insensitive") do
    d.check("dialog visible") { open_two.window.visible? }
    d.check("session row") { open_two.session_row.title == "Session bus log:" }
    d.check("system row") { open_two.system_row.title == "System bus log:" }
    d.check("open insensitive") { !open_two.open_button.sensitive? }
    d.shot("04-open-two", open_two.window)
  end

  d.step("close it") { open_two.window.close }

  d.step("the statistics sidebar opens") do
    app.windows.first.window.activate_action("statistics", nil)
  end

  d.step("the statistics tables are filled in") do
    pane = app.windows.first.statistics_pane
    d.check("sidebar visible") { app.windows.first.sidebar_toolbar.visible? }
    d.check("frequency rows") { pane.frequency_store.n_items.positive? }
    d.check("duration rows") { pane.duration_store.n_items.positive? }
    d.check("size rows") { pane.size_store.n_items.positive? }
    d.check("frequency column is not pinned to 120px") { pane.frequency_count_column.fixed_width <= 0 }
    d.shot("05-statistics")
  end

  d.step("selecting a message fills the details pane") do
    app.windows.first.canvas.drawing_area.grab_focus
    app.windows.first.canvas.send(:update_selection) { |selection| selection.first }
  end

  d.step("the details pane shows the selected message") do
    details = app.windows.first.details_view
    d.check("details visible") { details.container.visible? }
    d.check("path shown") { !details.path_row.subtitle.to_s.empty? }
    d.check("sender is escaped text, not markup") { !details.sender_row.subtitle.to_s.include?("<") }
    d.shot("06-details")
  end
end
