# frozen_string_literal: true

# Drives the whole of bustle-rb: every window, page, dialog, menu, action and
# keyboard shortcut the port claims, plus its empty and error states and its
# two command-line front doors.
#
#   nix develop --command xvfb-run -a ruby test/drive_bustle.rb
#
# The steps are grouped by the components in .reports/component-inventory.md
# and numbered the same way, so the coverage claim at the end can be checked
# against that catalogue. The one thing no step here can drive is a
# Gtk::FileDialog: GTK4 made it a one-shot async chooser with no signals, so
# the dialogs that wrap one (Open, Open-a-Pair's two choosers, Export as PDF,
# the recording's Save-As) are exercised by calling the code their callbacks
# call, and their own configuration — titles, filters, suggested names — is
# asserted on the chooser object instead. Component 21, the live bus monitor,
# needs a session bus of its own and lives in test/drive_recording.rb.

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "fileutils"
require "set"
require "stringio"
require "tmpdir"

require_relative "gtk_driver"

require "bustle/application"
require "bustle/diagram"
require "bustle/filter_dialog"
require "bustle/main"
require "bustle/marquee"
require "bustle/monitor"
require "bustle/noninteractive"
require "bustle/open_dialog"
require "bustle/open_two_dialog"
require "bustle/pcap_cli"
require "bustle/pdf_export"
require "bustle/record_address_dialog"
require "bustle/recorder"
require "bustle/translation"
require "bustle/types"
require "bustle/variant_formatter"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir

ROOT = File.expand_path("..", __dir__)
LOG = File.join(ROOT, "spec/fixtures/log-with-h.bustle")
MISSING_LOG = File.join(Dir.tmpdir, "bustle-no-such-log.bustle")
SCRATCH = Dir.mktmpdir("bustle-drive")

# Every component the drive exercises, by its number in
# .reports/component-inventory.md. A step adds its own as it runs, so the
# count at the end is observed rather than asserted up front.
COVERED = Set.new

def covers(*numbers) = numbers.each { |number| COVERED << number }

# A stand-in for the Process::Status the monitor reads an exit status off, so
# the three statuses pkexec hands back can be driven without a polkit prompt.
EXIT_STATUS = Struct.new(:exitstatus) do
  def signaled? = false

  def termsig = nil
end

def status_for(exitstatus) = EXIT_STATUS.new(exitstatus)

application = Bustle::Application.new(logs: [LOG], app_id: "org.rubygtkproject.Bustle.Drive")

# Captured as the run goes, so a later step can look at what an earlier one
# produced.
empty_window = nil
filter = nil
filter_hidden = nil
open_two = nil
open_two_opened = nil
record_address = nil
recorded_address = nil
shapes_before_filter = nil
recorded_temporary = nil
saved_log = nil
export_error = nil
about_dialog = nil

GtkDriver.drive(application, shots: ENV.fetch("BUSTLE_SHOTS", File.join(Dir.tmpdir, "bustle-shots"))) do |d, app|
  d.window { app.windows.first.window }

  # --- 1. the application, 2. the main window --------------------------------

  d.step("the log named on the command line loads into one window") do
    covers(1, 2)
    d.check("one window") { app.windows.length == 1 }
    d.check("canvas has shapes") { !app.windows.first.canvas.shapes.empty? }
    d.check("the window is no longer empty") { !app.windows.first.empty? }
    d.check("the diagram page is showing") do
      app.windows.first.stack.visible_child_name == Bustle::Window::CANVAS_PAGE
    end
    d.check("the stack carries all three pages") { app.windows.first.stack.pages.n_items == 3 }
    d.shot("01-diagram")
  end

  d.step("the window is titled after the log") do
    covers(2)
    window = app.windows.first
    d.check("window title is the filename") { window.window.title == File.basename(LOG) }
    d.check("header title is the filename") do
      window.header_bar.title_label.label == File.basename(LOG)
    end
    d.check("header subtitle is the directory") do
      window.header_bar.subtitle_label.label == File.dirname(LOG)
    end
  end

  d.step("LogDetails titles a pair and an unsaved recording as upstream does") do
    covers(2)
    d.check("a pair joins both names") do
      Bustle::Window::LogDetails.two("/a/one.bustle", "/b/two.bustle").title_pair ==
        ["one.bustle & two.bustle", "/a & /b"]
    end
    d.check("a recording is starred and has no directory") do
      Bustle::Window::LogDetails.recorded("/tmp/rec.bustle").then do |details|
        details.title_pair == ["*rec.bustle", ""] && details.directory.nil?
      end
    end
    d.check("the PDF name joins both logs") do
      Bustle::Window::LogDetails.two("/a/one.bustle", "/b/two.pcap").log_title == "one & two"
    end
  end

  # --- 3. the header bars ----------------------------------------------------

  d.step("the header bar carries upstream's controls") do
    covers(3)
    bar = app.windows.first.header_bar
    d.check("Record is a menu button with the record menu") do
      bar.record_button.menu_model == app.windows.first.menus.record_menu
    end
    d.check("Record is the suggested action") { bar.record_button.css_classes.include?("suggested-action") }
    d.check("Open is a menu button with the open menu") do
      bar.open_button.menu_model == app.windows.first.menus.open_menu
    end
    d.check("the main menu button carries the main menu") do
      bar.main_menu_button.menu_model == app.windows.first.menus.main_menu
    end
    d.check("Save is wired to win.save") { bar.save_button.action_name == "win.save" }
    d.check("Export is wired to win.export-pdf") { bar.export_button.action_name == "win.export-pdf" }
    d.check("Stop is hidden until a recording runs") { !bar.stop_button.visible? }
    d.check("Stop is the destructive action") { bar.stop_button.css_classes.include?("destructive-action") }
    d.check("the spinner is not spinning") { !bar.spinner.spinning? }
    d.shot("02-header", bar.header_bar)
  end

  d.step("the header titles escape markup rather than interpreting it") do
    covers(3)
    bar = app.windows.first.header_bar
    bar.set_title("a & b <c>", "/tmp/d'e")
    d.check("ampersand and angle brackets are escaped") do
      bar.title_label.label == "a &amp; b &lt;c&gt;"
    end
    d.check("the apostrophe is escaped") { bar.subtitle_label.label == "/tmp/d&apos;e" }
    bar.set_title(File.basename(LOG), File.dirname(LOG))
  end

  d.step("the sidebar header is the statistics switcher") do
    covers(3, 10)
    window = app.windows.first
    d.check("the switcher drives the statistics stack") do
      window.header_bar.stack_switcher.stack == window.statistics_pane.stack
    end
    d.check("the sidebar header shows no window buttons") do
      !window.header_bar.sidebar_header.show_end_title_buttons? &&
        !window.header_bar.sidebar_header.show_start_title_buttons?
    end
  end

  # --- 4. menus, actions and shortcuts ---------------------------------------

  d.step("every window action is installed") do
    covers(4)
    window = app.windows.first.window
    (Bustle::Menus::WINDOW_ACTIONS.keys + [Bustle::Menus::STATISTICS_ACTION]).each do |name|
      d.check("win.#{name} exists") { !window.lookup_action(name).nil? }
    end
  end

  d.step("every accelerator upstream's menu items advertise is bound") do
    covers(4)
    Bustle::Menus::WINDOW_ACTIONS.each do |name, accels|
      d.check("win.#{name} accels are #{accels.inspect}") do
        app.app.get_accels_for_action("win.#{name}") == accels
      end
    end
    d.check("win.statistics is F9") do
      app.app.get_accels_for_action("win.#{Bustle::Menus::STATISTICS_ACTION}") ==
        Bustle::Menus::STATISTICS_ACCELS
    end
  end

  d.step("the three menus carry upstream's items") do
    covers(4)
    menus = app.windows.first.menus
    d.check("the record menu has session, system and address") { menus.record_menu.n_items == 3 }
    d.check("the open menu has one and a pair") { menus.open_menu.n_items == 2 }
    d.check("the main menu is two sections") { menus.main_menu.n_items == 2 }
  end

  d.step("the log-dependent actions are enabled and Save is not") do
    covers(4)
    window = app.windows.first.window
    Bustle::Menus::NEEDS_LOG.each do |name|
      d.check("win.#{name} is enabled with a log open") { window.lookup_action(name).enabled? }
    end
    d.check("win.save is disabled until there is a recording to save") do
      !window.lookup_action(Bustle::Menus::SAVE_ACTION).enabled?
    end
  end

  # --- 5. the error state ----------------------------------------------------

  d.step("the error bar shows a title and details") do
    covers(5)
    app.windows.first.error_bar.show("Could not read '/no/such/log'", "No such file or directory")
  end

  d.step("the error bar is error-coloured and selectable") do
    covers(5)
    bar = app.windows.first.error_bar
    d.check("visible") { bar.container.visible? }
    d.check("error css class") { bar.container.css_classes.include?(Bustle::ErrorBar::CSS_CLASS) }
    d.check("title selectable") { bar.title_label.selectable? }
    d.check("details selectable") { bar.details_label.selectable? }
    d.check("details shown") { bar.details_label.visible? }
    d.check("close button carries an icon, not a label") do
      bar.close_button.icon_name == "window-close-symbolic" && bar.close_button.label.nil?
    end
    d.shot("03-error-bar")
  end

  d.step("the close button hides it") do
    covers(5)
    app.windows.first.error_bar.close_button.activate
  end

  d.step("hidden") do
    covers(5)
    d.check("not visible") { !app.windows.first.error_bar.container.visible? }
  end

  d.step("an error with no details shows only the title") do
    covers(5)
    app.windows.first.error_bar.show("Couldn't export log as PDF: nope")
  end

  d.step("the details label is hidden when there are none") do
    covers(5)
    bar = app.windows.first.error_bar
    d.check("the title is bold, with its apostrophe escaped") do
      bar.title_label.label == "<b>Couldn&apos;t export log as PDF: nope</b>"
    end
    d.check("details hidden") { !bar.details_label.visible? }
    bar.hide
  end

  # --- 8. the diagram canvas -------------------------------------------------

  d.step("the canvas steps by one message row") do
    covers(8)
    window = app.windows.first
    d.check("horizontal step is one event row") do
      window.canvas.scroller.hadjustment.step_increment == Bustle::Diagram::EVENT_HEIGHT
    end
    d.check("vertical step is one event row") do
      window.canvas.scroller.vadjustment.step_increment == Bustle::Diagram::EVENT_HEIGHT
    end
    d.check("the drawing area is as wide as the diagram") do
      Bustle::Diagram.diagram_dimensions(window.canvas.shapes).first.ceil ==
        window.canvas.drawing_area.size_request.first
    end
    d.check("the drawing area takes focus") { window.canvas.drawing_area.focusable? }
  end

  d.step("clicking the diagram selects the message under the pointer") do
    covers(8, 9)
    canvas = app.windows.first.canvas
    canvas.click_gesture.signal_emit(
      "pressed",
      1,
      Bustle::Diagram::TIMESTAMP_X,
      Bustle::Diagram::EVENT_HEIGHT * 3,
    )
  end

  d.step("a click selected something and filled the details pane") do
    covers(8, 9)
    window = app.windows.first
    d.check("a message is selected") do
      !window.canvas.instance_variable_get(:@selection).current.nil?
    end
    d.check("details visible") { window.details_view.container.visible? }
    d.check("path shown") { !window.details_view.path_row.subtitle.to_s.empty? }
    d.check("sender is escaped text, not markup") do
      !window.details_view.sender_row.subtitle.to_s.include?("<")
    end
    d.shot("04-selected")
  end

  d.step("Home selects the first message and End the last") do
    covers(8)
    canvas = app.windows.first.canvas
    press = ->(keyval) { canvas.key_controller.signal_emit(
      "key-pressed",
      keyval,
      0,
      0,
    ) }

    press.call(Gdk::Keyval::KEY_Home)
    canvas.instance_variable_get(:@selection).current.value.then do |first|
      press.call(Gdk::Keyval::KEY_End)
      canvas.instance_variable_get(:@selection).current.value.then do |last|
        d.check("Home and End pick different messages") { !first.equal?(last) }
        d.check("End is below Home") do
          canvas.instance_variable_get(:@selection).after.empty?
        end
      end
    end

    press.call(Gdk::Keyval::KEY_Home)
    d.check("Home leaves nothing above the selection") do
      canvas.instance_variable_get(:@selection).before.empty?
    end
  end

  d.step("Down and Up move the selection one message at a time") do
    covers(8)
    canvas = app.windows.first.canvas
    press = ->(keyval) { canvas.key_controller.signal_emit(
      "key-pressed",
      keyval,
      0,
      0,
    ) }
    selected = -> { canvas.instance_variable_get(:@selection).current.value }

    selected.call.then do |first|
      press.call(Gdk::Keyval::KEY_Down)
      d.check("Down moved on") { !selected.call.equal?(first) }
      press.call(Gdk::Keyval::KEY_Up)
      d.check("Up came back") { selected.call.equal?(first) }
    end
  end

  d.step("space scrolls down a page") do
    covers(8)
    canvas = app.windows.first.canvas
    vertical = canvas.scroller.vadjustment
    vertical.value = 0
    canvas.key_controller.signal_emit(
      "key-pressed",
      Gdk::Keyval::KEY_space,
      0,
      0,
    )
    d.check("space scrolled down a page") { vertical.value.positive? }
  end

  d.step("a modified key is left for the rest of the app") do
    covers(8)
    canvas = app.windows.first.canvas
    d.check("Ctrl+Down is not handled by the canvas") do
      canvas.key_controller.signal_emit(
        "key-pressed",
        Gdk::Keyval::KEY_Down,
        0,
        Gdk::ModifierType::CONTROL_MASK,
      ) == false
    end
  end

  d.step("scroll_to_bottom follows the end of a growing diagram") do
    covers(8)
    canvas = app.windows.first.canvas
    canvas.scroll_to_bottom
    canvas.scroller.vadjustment.then do |adjustment|
      d.check("the view sits on the last page") do
        adjustment.value == [0, adjustment.upper - adjustment.page_size].max
      end
    end
  end

  d.step("--debug draws every shape's bounding box without falling over") do
    covers(1, 8)
    Cairo::ImageSurface.new(:argb32, 400, 400).then do |surface|
      Cairo::Context.new(surface).then do |context|
        Bustle::Diagram.draw_diagram(context, app.windows.first.canvas.shapes, show_bounds: true)
      end
      d.check("a debug render produced a surface") { surface.width == 400 }
    end
  end

  # --- 9. the details pane, empty state --------------------------------------

  d.step("clearing the selection hides the details pane") do
    covers(9)
    app.windows.first.details_view.update(nil)
    d.check("details hidden") { !app.windows.first.details_view.container.visible? }
  end

  d.step("the details pane shows the message again when one is selected") do
    covers(9)
    window = app.windows.first
    # End, not Home: the pane only repopulates when the selection actually
    # moves, and Home is where the last step left it.
    window.canvas.key_controller.signal_emit(
      "key-pressed",
      Gdk::Keyval::KEY_End,
      0,
      0,
    )
    d.check("details visible again") { window.details_view.container.visible? }
    d.check("a type is named") { !window.details_view.type_row.subtitle.to_s.empty? }
    d.check("the member is marked up in bold") do
      window.details_view.member_row.subtitle.to_s.include?("<b>")
    end
  end

  # A step of its own: a widget that only just became visible has not been
  # laid out yet, and a screenshot of it comes back with no render node.
  d.step("the details pane renders") do
    covers(9)
    d.shot("05-details")
  end

  # --- 10. the statistics sidebar --------------------------------------------

  d.step("F9's action opens the statistics sidebar") do
    covers(4, 10)
    app.windows.first.window.activate_action(Bustle::Menus::STATISTICS_ACTION, nil)
  end

  d.step("the statistics tables are filled in") do
    covers(10)
    window = app.windows.first
    pane = window.statistics_pane
    d.check("sidebar visible") { window.sidebar_toolbar.visible? }
    d.check("the action remembers it is on") { window.menus.statistics_active? }
    d.check("frequency rows") { pane.frequency_store.n_items.positive? }
    d.check("duration rows") { pane.duration_store.n_items.positive? }
    d.check("size rows") { pane.size_store.n_items.positive? }
    d.check("frequency column is not pinned to 120px") { pane.frequency_count_column.fixed_width <= 0 }
    d.shot("06-statistics")
  end

  d.step("the switcher moves between the three tables") do
    covers(10)
    pane = app.windows.first.statistics_pane
    [
      Bustle::StatisticsPane::DURATIONS_PAGE,
      Bustle::StatisticsPane::SIZES_PAGE,
      Bustle::StatisticsPane::FREQUENCIES_PAGE,
    ].each do |page|
      pane.stack.visible_child_name = page
      d.check("the #{page} table shows") { pane.stack.visible_child_name == page }
    end
    pane.stack.visible_child_name = Bustle::StatisticsPane::SIZES_PAGE
  end

  d.step("the sizes table renders") do
    covers(10)
    d.shot("07-statistics-sizes", app.windows.first.statistics_pane.stack)
    app.windows.first.statistics_pane.stack.visible_child_name = Bustle::StatisticsPane::FREQUENCIES_PAGE
  end

  d.step("the statistics action toggles the sidebar back off") do
    covers(4, 10)
    app.windows.first.window.activate_action(Bustle::Menus::STATISTICS_ACTION, nil)
  end

  d.step("the sidebar is hidden again") do
    covers(4, 10)
    window = app.windows.first
    d.check("sidebar hidden") { !window.sidebar_toolbar.visible? }
    d.check("the action remembers it is off") { !window.menus.statistics_active? }
    window.window.activate_action(Bustle::Menus::STATISTICS_ACTION, nil)
  end

  # --- 11. the service filter dialog -----------------------------------------

  d.step("the filter dialog opens over the real log's participants") do
    covers(11)
    window = app.windows.first
    shapes_before_filter = window.canvas.shapes.length
    window.instance_variable_get(:@result).applications.session_participants.then do |participants|
      filter = Bustle::FilterDialog.new(
        participants: participants,
        hidden:       Set.new,
        on_apply:     ->(hidden) { filter_hidden = hidden },
      )
      filter.present(window.window)
    end
  end

  d.step("the filter list is banded and sized as upstream's is") do
    covers(11)
    d.check("dialog visible") { filter.window.visible? }
    d.check("banding class") { filter.list_box.css_classes.include?(Bustle::FilterDialog::LIST_CSS_CLASS) }
    d.check("name view 600x371") do
      filter.list_box.size_request == [Bustle::FilterDialog::NAME_VIEW_WIDTH, Bustle::FilterDialog::NAME_VIEW_HEIGHT]
    end
    d.check("instructions 600 wide") { filter.instructions.size_request == [Bustle::FilterDialog::NAME_VIEW_WIDTH, -1] }
    d.check("one row per participant") do
      filter.list_box.children.length ==
        app.windows.first.instance_variable_get(:@result).applications.session_participants.length
    end
    d.check("every service starts ticked") do
      filter.instance_variable_get(:@rows).values.all?(&:active?)
    end
    d.shot("08-filter", filter.window)
  end

  d.step("unticking a service and closing the dialog applies the filter") do
    covers(11)
    filter.instance_variable_get(:@rows).then do |checks|
      checks.keys.first.then do |name|
        checks.fetch(name).active = false
        filter.window.close
      end
    end
  end

  d.step("the filter came back with the unticked service hidden") do
    covers(11)
    d.check("one service is hidden") { filter_hidden&.length == 1 }
    app.windows.first.send(:apply_filter, filter_hidden)
  end

  d.step("hiding a service redraws with fewer shapes") do
    covers(11)
    d.check("the diagram shrank") { app.windows.first.canvas.shapes.length < shapes_before_filter }
    d.shot("09-filtered")
  end

  d.step("unhiding everything puts the diagram back") do
    covers(11)
    app.windows.first.send(:apply_filter, Set.new)
    d.check("the diagram is whole again") { app.windows.first.canvas.shapes.length == shapes_before_filter }
  end

  # --- 12. open a pair of logs ----------------------------------------------

  d.step("the open-a-pair dialog opens") do
    covers(12)
    open_two = Bustle::OpenTwoDialog.new(
      on_open: ->(session_path, system_path) { open_two_opened = [session_path, system_path] },
    )
    open_two.present(app.windows.first.window)
  end

  d.step("it asks for two logs and Open is insensitive") do
    covers(12)
    d.check("dialog visible") { open_two.window.visible? }
    d.check("session row") { open_two.session_row.title == "Session bus log:" }
    d.check("system row") { open_two.system_row.title == "System bus log:" }
    d.check("neither row has a log yet") { open_two.session_row.subtitle == "(none chosen)" }
    d.check("open insensitive") { !open_two.open_button.sensitive? }
    d.check("each row has its own chooser, titled for its bus") do
      open_two.send(:file_dialog, :session).title == "Select session bus log" &&
        open_two.send(:file_dialog, :system).title == "Select system bus log"
    end
    d.shot("10-open-two", open_two.window)
  end

  d.step("choosing the session log alone leaves Open insensitive") do
    covers(12)
    open_two.send(:chosen, :session, LOG)
    d.check("the row shows the chosen path") { open_two.session_row.subtitle == LOG }
    d.check("open is still insensitive") { !open_two.open_button.sensitive? }
    d.check("the other chooser moved to the same folder") do
      open_two.send(:file_dialog, :system).initial_folder&.path == File.dirname(LOG)
    end
  end

  d.step("choosing the second log makes Open sensitive") do
    covers(12)
    open_two.send(:chosen, :system, LOG)
    d.check("open is sensitive") { open_two.open_button.sensitive? }
    d.check("the first choice was not overwritten") { open_two.session_row.subtitle == LOG }
  end

  d.step("the filled-in pair dialog renders") do
    covers(12)
    d.shot("11-open-two-filled", open_two.window)
  end

  d.step("Open hands both logs back and closes") do
    covers(12)
    open_two.open_button.activate
  end

  d.step("both paths came back") do
    covers(12)
    d.check("the pair is the two chosen logs") { open_two_opened == [LOG, LOG] }
    d.check("the dialog closed") { !open_two.window.visible? }
  end

  d.step("a pair of logs draws one diagram") do
    covers(2, 12)
    app.windows.first.load(Bustle::Window::LogDetails.two(LOG, LOG))
  end

  d.step("the pair is drawn and titled as a pair") do
    covers(2, 12)
    window = app.windows.first
    d.check("both logs are in the title") { window.window.title.include?(" & ") }
    d.check("shapes were drawn") { !window.canvas.shapes.empty? }
    d.check("the pair has more participants than one log alone") do
      window.instance_variable_get(:@result).applications.session_participants.length.positive?
    end
    d.shot("12-pair")
  end

  # The pair's diagram is wider than the window, which is what makes the
  # horizontal keys do anything: a single log's diagram fits, so Left and
  # Right correctly have nothing to scroll.
  d.step("Right and Left scroll the wide diagram by one message row") do
    covers(8)
    canvas = app.windows.first.canvas
    press = ->(keyval) { canvas.key_controller.signal_emit(
      "key-pressed",
      keyval,
      0,
      0,
    ) }
    horizontal = canvas.scroller.hadjustment

    d.check("the pair's diagram is wider than the window") do
      horizontal.upper > horizontal.page_size
    end

    horizontal.value = 0
    press.call(Gdk::Keyval::KEY_Right)
    d.check("Right scrolled one event row right") { horizontal.value == Bustle::Diagram::EVENT_HEIGHT }
    press.call(Gdk::Keyval::KEY_Left)
    d.check("Left came back") { horizontal.value.zero? }

    horizontal.value = horizontal.upper
    press.call(Gdk::Keyval::KEY_Right)
    d.check("Right never scrolls past the last page") do
      horizontal.value == horizontal.upper - horizontal.page_size
    end
  end

  d.step("back to the single log") do
    covers(2)
    app.windows.first.load(Bustle::Window::LogDetails.single(LOG))
    d.check("titled after the one log again") { app.windows.first.window.title == File.basename(LOG) }
  end

  # --- 13. record an arbitrary address ---------------------------------------

  d.step("the record-address dialog opens") do
    covers(13)
    record_address = Bustle::RecordAddressDialog.new(on_record: ->(address) { recorded_address = address })
    record_address.present(app.windows.first.window)
  end

  d.step("Record is insensitive until an address is typed") do
    covers(13)
    d.check("dialog visible") { record_address.window.visible? }
    d.check("the row asks for an address") { record_address.address_row.title == "Address:" }
    d.check("upstream's example is the group description") do
      record_address.group.description.to_s.start_with?("e.g. unix:abstract=")
    end
    d.check("record insensitive") { !record_address.record_button.sensitive? }
    d.check("record is the suggested action") do
      record_address.record_button.css_classes.include?("suggested-action")
    end
    d.shot("13-record-address", record_address.window)
  end

  d.step("typing an address switches Record on") do
    covers(13)
    record_address.address_row.text = "unix:abstract=/tmp/dbus-drive,guid=deadbeef"
    d.check("record sensitive") { record_address.record_button.sensitive? }
  end

  d.step("emptying it switches Record off again") do
    covers(13)
    record_address.address_row.text = ""
    d.check("record insensitive") { !record_address.record_button.sensitive? }
    record_address.address_row.text = "unix:abstract=/tmp/dbus-drive,guid=deadbeef"
  end

  d.step("Record hands the address back and closes") do
    covers(13)
    record_address.record_button.activate
  end

  d.step("the address came back") do
    covers(13)
    d.check("the typed address was handed over") do
      recorded_address == "unix:abstract=/tmp/dbus-drive,guid=deadbeef"
    end
    d.check("the dialog closed") { !record_address.window.visible? }
    d.check("an address is its own monitor target") do
      Bustle::Monitor.target_for(recorded_address) == recorded_address
    end
    d.check("the two bus types pass straight through") do
      Bustle::Monitor.target_for(Bustle::Monitor::SESSION_BUS) == Bustle::Monitor::SESSION_BUS &&
        Bustle::Monitor.target_for(Bustle::Monitor::SYSTEM_BUS) == Bustle::Monitor::SYSTEM_BUS
    end
    d.check("each target describes itself for the header bar") do
      Bustle::Monitor.describe(Bustle::Monitor::SESSION_BUS) == "session bus" &&
        Bustle::Monitor.describe(Bustle::Monitor::SYSTEM_BUS) == "system bus" &&
        Bustle::Monitor.describe(recorded_address) == recorded_address
    end
  end

  d.step("Return in the address entry records too") do
    covers(13)
    Bustle::RecordAddressDialog.new(on_record: ->(address) { recorded_address = address }).then do |dialog|
      dialog.present(app.windows.first.window)
      d.check("Record is the window's default widget, as upstream's response is") do
        dialog.window.default_widget == dialog.record_button
      end
      dialog.address_row.signal_emit("entry-activated")
      d.check("Return on an empty address does nothing, as an insensitive default does") do
        recorded_address == "unix:abstract=/tmp/dbus-drive,guid=deadbeef"
      end
      dialog.address_row.text = "unix:path=/tmp/typed-then-entered"
      dialog.address_row.signal_emit("entry-activated")
      d.check("Return hands the typed address back") do
        recorded_address == "unix:path=/tmp/typed-then-entered"
      end
      d.check("and closes the dialog") { !dialog.window.visible? }
    end
  end

  d.step("the record-address dialog's Cancel closes it with nothing recorded") do
    covers(13)
    Bustle::RecordAddressDialog.new(on_record: ->(_address) { recorded_address = :cancelled })
                               .tap { |dialog| dialog.present(app.windows.first.window) }
                               .then do |dialog|
      dialog.cancel_button.activate
      d.check("cancelling recorded nothing") { recorded_address != :cancelled }
    end
  end

  # --- 14. open one log ------------------------------------------------------

  d.step("the Open chooser is configured for D-Bus logs") do
    covers(14)
    Bustle::OpenDialog.new(on_chosen: ->(_path) {}).dialog.then do |chooser|
      d.check("titled Open a Log") { chooser.title == "Open a Log" }
      d.check("modal") { chooser.modal? }
      d.check("two filters: logs and everything") { chooser.filters.n_items == 2 }
      d.check("the log filter is named") { chooser.filters.get_item(0).name == "D-Bus logs" }
      d.check("the fallback filter is named") { chooser.filters.get_item(1).name == "All files" }
    end
  end

  d.step("Open loads into the initial window, as upstream does") do
    covers(1, 14)
    app.windows.length.then do |before|
      app.windows.first.send(:load_in_initial_window, Bustle::Window::LogDetails.single(LOG))
      empty_window = app.windows.last
      d.check("a second window was opened for it") { app.windows.length == before + 1 }
      d.check("the second window has the log") { !empty_window.empty? }
      d.check("the first window kept its own log") { !app.windows.first.empty? }
    end
  end

  # --- 6. the empty state ----------------------------------------------------

  d.step("a window with no log shows the welcome page") do
    covers(1, 6)
    empty_window = app.consume_initial_window
    d.check("a third window") { app.windows.length == 3 }
    d.check("it is empty") { empty_window.empty? }
    d.check("the instructions page is showing") do
      empty_window.stack.visible_child_name == Bustle::Window::INSTRUCTIONS_PAGE
    end
    d.check("the welcome page wears the app icon") do
      empty_window.welcome_page.status_page.icon_name == Bustle::WelcomePage::ICON_NAME
    end
    d.check("it welcomes you") { empty_window.welcome_page.status_page.title == "Welcome to Bustle" }
    d.check("the icon theme can actually find that icon") do
      Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?(Bustle::WelcomePage::ICON_NAME)
    end
    d.check("and the window and about dialog's logo too") do
      Gtk::IconTheme.get_for_display(Gdk::Display.default).has_icon?(Bustle::AboutDialog::LOGO_ICON_NAME)
    end
    d.check("the instructions are markup and mention Record") do
      empty_window.welcome_page.description_label.use_markup? &&
        empty_window.welcome_page.description_label.label.include?("<b>Record</b>")
    end
    d.check("the log-dependent actions are off in an empty window") do
      Bustle::Menus::NEEDS_LOG.none? { |name| empty_window.window.lookup_action(name).enabled? }
    end
  end

  d.step("the welcome page renders") do
    covers(6)
    d.shot("14-welcome", empty_window.window)
  end

  # --- 5. the error state, from a log that will not load ---------------------

  d.step("a log that will not load leaves the window empty and explains why") do
    covers(5, 6)
    FileUtils.rm_f(MISSING_LOG)
    empty_window.load(Bustle::Window::LogDetails.single(MISSING_LOG))
  end

  d.step("the error bar names the file and the reason") do
    covers(5, 6)
    d.check("the window is still empty") { empty_window.empty? }
    d.check("still on the welcome page") do
      empty_window.stack.visible_child_name == Bustle::Window::INSTRUCTIONS_PAGE
    end
    d.check("the error bar is up") { empty_window.error_bar.container.visible? }
    d.check("it names the file, bold and escaped") do
      # Exactly what the window builds: upstream's msgid through the
      # catalogue, the path substituted in, escaped, and emboldened.
      empty_window.error_bar.title_label.label ==
        Bustle::Marquee.b(
          Bustle::Marquee.escape(format(Bustle._("Could not read '%s'"), MISSING_LOG)),
        ).to_markup
    end
    d.check("it gives a reason") { !empty_window.error_bar.details_label.label.to_s.empty? }
    d.shot("15-load-error", empty_window.window)
  end

  d.step("a file that is not a pcap at all is reported too") do
    covers(5)
    File.join(SCRATCH, "not-a-log.bustle").then do |path|
      File.write(path, "this is not a pcap file")
      empty_window.load(Bustle::Window::LogDetails.single(path))
      d.check("still empty") { empty_window.empty? }
      d.check("the error bar names it") { empty_window.error_bar.title_label.label.include?(path) }
    end
  end

  # --- 7. the waiting page, 16. the recording flow --------------------------

  # Window#begin_recording would start a real dbus-monitor, which needs a
  # session bus of its own; test/drive_recording.rb does that end to end. What
  # is driven here is everything begin_recording does around it: hide the
  # error bar, retitle the header, show the waiting page.
  d.step("a recording shows the please-hold page") do
    covers(7, 16)
    recording_title = format(Bustle._("Recording %s&#8230;"), Bustle::Monitor.describe(Bustle::Monitor::SESSION_BUS))
    empty_window.error_bar.hide
    empty_window.header_bar.start_recording(recording_title)
    empty_window.show_waiting
  end

  d.step("the please-hold page spins while the bus is quiet") do
    covers(7, 16)
    page = empty_window.please_hold_page
    d.check("the please-hold page is showing") do
      empty_window.stack.visible_child_name == Bustle::Window::PLEASE_HOLD_PAGE
    end
    d.check("its label is markup, as upstream's msgid is") do
      page.holding_label.use_markup? && page.holding_label.label.start_with?("<big><b>")
    end
    d.check("the page spinner is spinning") { page.spinner.spinning? }
    d.check("the header says which bus is being recorded") do
      empty_window.header_bar.title_label.label == "Recording session bus&#8230;"
    end
    d.check("nothing is left of the last error") { !empty_window.error_bar.container.visible? }
    d.check("Stop replaced Record and Open") do
      empty_window.header_bar.stop_button.visible? &&
        !empty_window.header_bar.record_button.visible? &&
        !empty_window.header_bar.open_button.visible?
    end
    d.check("the header spinner is spinning") { empty_window.header_bar.spinner.spinning? }
    d.check("the subtitle counts no messages yet") do
      empty_window.header_bar.subtitle_label.label == "Logged <b>0</b> messages"
    end
    d.shot("16-please-hold", empty_window.window)
  end

  d.step("each batch of messages updates the count and the diagram") do
    covers(16)
    Bustle::Loader.read_log(LOG).then do |_warnings, messages|
      empty_window.send(:recording_progress, messages.length, Bustle::Renderer.process(messages, []))
    end
  end

  d.step("the diagram grew and the subtitle counted it") do
    covers(16)
    d.check("the canvas page is showing") do
      empty_window.stack.visible_child_name == Bustle::Window::CANVAS_PAGE
    end
    d.check("shapes were drawn") { !empty_window.canvas.shapes.empty? }
    d.check("the subtitle counts the messages") do
      empty_window.header_bar.subtitle_label.label.match?(%r{Logged <b>\d+</b> messages})
    end
    d.shot("17-recording")
  end

  d.step("a recording that produced something is re-read off its temporary file") do
    covers(16)
    recorded_temporary = File.join(SCRATCH, "2026-01-01 00:00:00.bustle")
    FileUtils.cp(LOG, recorded_temporary)
    empty_window.send(:recording_finished, recorded_temporary, true)
  end

  d.step("the finished recording is an unsaved log with Save switched on") do
    covers(16)
    d.check("Record and Open are back") do
      empty_window.header_bar.record_button.visible? && empty_window.header_bar.open_button.visible?
    end
    d.check("Stop is gone") { !empty_window.header_bar.stop_button.visible? }
    d.check("the spinner stopped") { !empty_window.header_bar.spinner.spinning? }
    d.check("the title is starred, as an unsaved recording is") do
      empty_window.window.title == "*#{File.basename(recorded_temporary)}"
    end
    d.check("Save is enabled now there is something to save") do
      empty_window.window.lookup_action(Bustle::Menus::SAVE_ACTION).enabled?
    end
    d.shot("18-recorded", empty_window.window)
  end

  d.step("the Save-As chooser suggests the temporary file's own name") do
    covers(16)
    chosen = nil
    Bustle::Recorder.choose_file(name: File.basename(recorded_temporary), parent: empty_window.window) do |path|
      chosen = path
    end
    d.check("nothing was saved without the user choosing") { chosen.nil? }
  end

  d.step("saving moves the recording where it was asked to go") do
    covers(16)
    saved_log = File.join(SCRATCH, "saved.bustle")
    empty_window.send(:save_recording, recorded_temporary, saved_log)
  end

  d.step("the saved log is an ordinary log now") do
    covers(16)
    d.check("the file moved") { File.exist?(saved_log) && !File.exist?(recorded_temporary) }
    d.check("Save went back off") do
      !empty_window.window.lookup_action(Bustle::Menus::SAVE_ACTION).enabled?
    end
    d.check("the title lost its asterisk") { empty_window.window.title == "saved.bustle" }
    d.check("no error") { !empty_window.error_bar.container.visible? }
  end

  d.step("a save that fails explains how to recover the log by hand") do
    covers(5, 16)
    empty_window.send(:save_recording, File.join(SCRATCH, "gone.bustle"), File.join(SCRATCH, "nowhere.bustle"))
  end

  d.step("the error bar carries the recovery advice") do
    covers(5, 16)
    d.check("the error bar is up") { empty_window.error_bar.container.visible? }
    d.check("it says saving failed") do
      empty_window.error_bar.title_label.label.start_with?("<b>Couldn&apos;t save log: ")
    end
    d.check("it names the temporary file to recover") do
      empty_window.error_bar.details_label.label.include?(File.join(SCRATCH, "gone.bustle"))
    end
    d.shot("19-save-error", empty_window.window)
    empty_window.error_bar.hide
  end

  d.step("a recording that produced nothing leaves the window as it found it") do
    covers(16)
    app.consume_initial_window.then do |window|
      window.header_bar.start_recording("Recording session bus…")
      window.show_waiting
      window.send(:recording_finished, File.join(SCRATCH, "empty.bustle"), false)
      d.check("the window is empty again") { window.empty? }
      d.check("back on the welcome page") do
        window.stack.visible_child_name == Bustle::Window::INSTRUCTIONS_PAGE
      end
      d.check("the title was cleared") { window.header_bar.title_label.label == "" }
      d.check("it is the window the next Open will use") { app.consume_initial_window.equal?(window) }
    end
  end

  # --- 17. the unsaved-recording confirmation --------------------------------

  d.step("closing an unsaved recording asks before it goes") do
    covers(17)
    app.consume_initial_window.then do |window|
      FileUtils.cp(LOG, File.join(SCRATCH, "unsaved.bustle"))
      window.load(Bustle::Window::LogDetails.recorded(File.join(SCRATCH, "unsaved.bustle")))
      d.check("close is refused until the question is answered") { window.send(:prompt_to_save) == true }
      window.send(:save_prompt).then do |prompt|
        d.check("the heading names the log") { prompt.heading.include?("unsaved.bustle") }
        d.check("three responses: save, close without saving, cancel") do
          %w[save close cancel].all? { |response| prompt.has_response?(response) }
        end
        d.check("Save is the default") { prompt.default_response == "save" }
        d.check("Cancel is what dismissing it means") { prompt.close_response == "cancel" }
        d.check("Close Without Saving is destructive") do
          prompt.get_response_appearance("close") == Adwaita::ResponseAppearance::DESTRUCTIVE
        end
      end
    end
  end

  d.step("the save prompt renders") do
    covers(17)
    d.shot("20-save-prompt", app.windows.last.send(:save_prompt))
  end

  d.step("a saved log closes without a word") do
    covers(17)
    app.windows.first.then do |window|
      d.check("an ordinary log needs no prompt") { window.send(:prompt_to_save) == false }
    end
  end

  d.step("answering Close Without Saving lets the window go") do
    covers(17)
    app.windows.last.then do |window|
      app.windows.length.then do |before|
        window.send(:save_prompt).signal_emit("response", "close")
        d.check("the window went away") { window.window.visible? == false }
        d.check("the other windows are untouched") { app.windows.length == before }
      end
    end
  end

  # --- 15. export the diagram as PDF -----------------------------------------

  d.step("the PDF chooser suggests the log's name and folder") do
    covers(15)
    Bustle::PdfExport.new(
      shapes:         app.windows.first.canvas.shapes,
      suggested_name: "log-with-h",
      directory:      File.dirname(LOG),
    ).dialog.then do |chooser|
      d.check("titled Export as PDF") { chooser.title == "Export as PDF" }
      d.check("the name is the log's with .pdf on it") { chooser.initial_name == "log-with-h.pdf" }
      d.check("it starts in the log's own folder") { chooser.initial_folder&.path == File.dirname(LOG) }
    end
  end

  d.step("exporting writes the whole diagram to one tall PDF page") do
    covers(15)
    exported = nil
    File.join(SCRATCH, "diagram.pdf").then do |path|
      Bustle::PdfExport.new(
        shapes:         app.windows.first.canvas.shapes,
        suggested_name: "diagram",
        on_success:     ->(written) { exported = written },
        on_error:       ->(message) { export_error = message },
      ).send(:export, path)

      d.check("the export reported success") { exported == path }
      d.check("no error") { export_error.nil? }
      d.check("a PDF was written") { File.read(path, 5) == "%PDF-" }
      d.check("it is the size of the whole diagram") do
        File.size(path).positive? &&
          Bustle::Diagram.diagram_dimensions(app.windows.first.canvas.shapes).all?(&:positive?)
      end
    end
  end

  d.step("an export that cannot be written reports it rather than crashing") do
    covers(5, 15)
    export_error = nil
    Bustle::PdfExport.new(
      shapes:         app.windows.first.canvas.shapes,
      suggested_name: "diagram",
      on_error:       ->(message) { export_error = message },
    ).send(:export, "/proc/nowhere/diagram.pdf")

    d.check("the failure was reported") { export_error.to_s.start_with?("Couldn't export log as PDF: ") }
  end

  # --- 18. the about dialog --------------------------------------------------

  d.step("the about dialog opens") do
    covers(4, 18)
    app.windows.first.window.activate_action("about", nil)
  end

  d.step("it credits upstream and carries the licence") do
    covers(18)
    about_dialog = Bustle::AboutDialog.new
    about_dialog.present(app.windows.first.window)
    about_dialog.then do |about|
      about.dialog.then do |dialog|
        d.check("named Bustle") { dialog.program_name == "Bustle" }
        d.check("upstream's own tagline") { dialog.comments == "Someone's favourite D-Bus profiler" }
        d.check("the port's version") { dialog.version == Bustle::Rb::Version::VERSION }
        d.check("upstream's website") { dialog.website == Bustle::AboutDialog::WEBSITE }
        d.check("upstream's copyright") { dialog.copyright == Bustle::AboutDialog::COPYRIGHT }
        d.check("all ten authors") { dialog.authors.length == Bustle::AboutDialog::AUTHORS.length }
        d.check("the licence text was read off disk") { dialog.license.to_s.length > 100 }
        d.check("the app's own logo") { dialog.logo_icon_name == Bustle::AboutDialog::LOGO_ICON_NAME }
      end
    end
  end

  d.step("the about dialog renders") do
    covers(18)
    d.shot("21-about", about_dialog.dialog)
    about_dialog.dialog.close
  end

  # --- 19. the batch CLI modes ----------------------------------------------

  d.step("--count prints message frequencies, busiest first") do
    covers(19)
    StringIO.new.then do |out|
      d.check("it succeeded") { Bustle::Noninteractive.run_count(LOG, output: out) == true }
      out.string.lines.then do |lines|
        d.check("it printed something") { !lines.empty? }
        d.check("each line is a count, a kind and a member") do
          lines.all? { |line| line.match?(/^\s+\d+\s+(method|signal)\s+\S+/) }
        end
        d.check("busiest first") do
          lines.map { |line| line[/\d+/].to_i }.then { |counts| counts == counts.sort.reverse }
        end
      end
    end
  end

  d.step("--time prints method durations") do
    covers(19)
    StringIO.new.then do |out|
      d.check("it succeeded") { Bustle::Noninteractive.run_time(LOG, output: out) == true }
      d.check("each line is total, calls, mean and a member") do
        out.string.lines.all? { |line| line.match?(/^\s+[\d.]+\s+\d+\s+[\d.]+\s+\S+/) }
      end
    end
  end

  d.step("--dot prints a digraph") do
    covers(19)
    StringIO.new.then do |out|
      d.check("it succeeded") { Bustle::Noninteractive.run_dot(LOG, output: out) == true }
      d.check("it opens a digraph") { out.string.lines.first.chomp == "digraph bustle {" }
      d.check("it closes it") { out.string.lines.last.chomp == "}" }
      d.check("it has edges") { out.string.include?("->") }
    end
  end

  d.step("a batch mode on a log that will not load fails") do
    covers(5, 19)
    StringIO.new.then do |out|
      d.check("it reported failure") { Bustle::Noninteractive.run_count(MISSING_LOG, output: out) == false }
      d.check("it printed nothing to stdout") { out.string.empty? }
    end
  end

  d.step("the command line routes each mode and refuses the rest") do
    covers(1, 19)
    d.check("--count takes exactly one log") { Bustle::Main.new(["--count", LOG]).run.zero? }
    d.check("--count with two logs is a usage error") { Bustle::Main.new(["--count", LOG, LOG]).run == 1 }
    d.check("--count with --debug after it is a usage error too, as runOne makes it") do
      Bustle::Main.new(["--count", "--debug", LOG]).run == 1
    end
    d.check("--help is not an error") { Bustle::Main.new(["--help"]).run.zero? }
    d.check("--help only counts as the whole command line") do
      Bustle::Main.new(["--count", LOG, "--help"]).send(:command) == :batch
    end
    d.check("--pair is a pair only with two logs after it") do
      Bustle::Main.new(["--pair", LOG, LOG]).send(:command) == :pair &&
        Bustle::Main.new(["--pair", LOG]).send(:command) == :interactive
    end
    d.check("only --debug is stripped, so a mistyped flag reaches the loader") do
      Bustle::Main.new(["--debug", "--nonesuch", LOG]).send(:arguments) == ["--nonesuch", LOG]
    end
    d.check("running anything sets GLib's application name, as upstream does first") do
      GLib.application_name == Bustle._("Bustle")
    end
  end

  # --- 20. the bustle-pcap recorder binary ----------------------------------

  d.step("bustle-pcap --help prints GOption's own help") do
    covers(20)
    StringIO.new.then do |out|
      d.check("exit 0") { Bustle::PcapCli.run(["--help"], output: out, errors: StringIO.new).zero? }
      d.check("it is upstream's help, byte for byte") { out.string == Bustle::PcapCli::USAGE }
    end
  end

  d.step("bustle-pcap --version prints the version notice") do
    covers(20)
    StringIO.new.then do |out|
      d.check("exit 0") { Bustle::PcapCli.run(["--version"], output: out, errors: StringIO.new).zero? }
      d.check("it names bustle-pcap and the version") do
        out.string.start_with?("bustle-pcap #{Bustle::Rb::VERSION}")
      end
    end
  end

  d.step("bustle-pcap refuses a missing or doubled argument") do
    covers(20)
    StringIO.new.then do |errors|
      d.check("no filename is a usage error") do
        Bustle::PcapCli.run([], output: StringIO.new, errors: errors) == Bustle::PcapCli::USAGE_EXIT_STATUS
      end
      d.check("it says exactly one filename") do
        errors.string.start_with?("You must specify exactly one output filename")
      end
    end

    StringIO.new.then do |errors|
      d.check("two buses is a usage error") do
        Bustle::PcapCli.run(["-e", "-y", "out.pcap"], output: StringIO.new, errors: errors) ==
          Bustle::PcapCli::USAGE_EXIT_STATUS
      end
      d.check("it says only one bus") do
        errors.string.start_with?("You may only specify one of --session, --system and --address")
      end
    end

    StringIO.new.then do |errors|
      d.check("an unknown option is a usage error") do
        Bustle::PcapCli.run(["--nonsense", "out.pcap"], output: StringIO.new, errors: errors) ==
          Bustle::PcapCli::USAGE_EXIT_STATUS
      end
      d.check("it names the option it could not parse") { errors.string.include?("--nonsense") }
    end
  end

  d.step("bustle-pcap parses GOption's grammar") do
    covers(20)
    Bustle::PcapCli.new(["-qa", "unix:path=/tmp/sock", "out.pcap"]).then do |cli|
      cli.send(:parse)
      d.check("a bundled short option takes the next word") do
        cli.instance_variable_get(:@address) == "unix:path=/tmp/sock"
      end
      d.check("the rest of the bundle still applies") { cli.send(:quiet?) == true }
      d.check("the filename survived") { cli.send(:filename) == "out.pcap" }
      d.check("an address beats the default session bus") { cli.send(:target) == "unix:path=/tmp/sock" }
    end

    Bustle::PcapCli.new(["--address=unix:path=/tmp/other", "--", "-weird-name"]).then do |cli|
      cli.send(:parse)
      d.check("a long option takes its argument after =") do
        cli.instance_variable_get(:@address) == "unix:path=/tmp/other"
      end
      d.check("-- ends the options") { cli.send(:filename) == "-weird-name" }
    end

    Bustle::PcapCli.new(["out.pcap"]).then do |cli|
      cli.send(:parse)
      d.check("the session bus is the default") { cli.send(:target) == Bustle::Monitor::SESSION_BUS }
    end
  end

  d.step("bustle-pcap exits as upstream's main does") do
    covers(20)
    # Upstream's only exit(1) is a monitor that would not construct; an error
    # reported through ::stopped while the recording was under way is printed
    # by stopped_cb and main still returns 0.
    File.join(SCRATCH, "pcap-cli-runtime.bustle").then do |path|
      StringIO.new.then do |out|
        StringIO.new.then do |errors|
          d.check("a bus that cannot be monitored is an error, not an exit status") do
            Bustle::PcapCli.run(
              ["--address=unix:path=/nonexistent/socket", path],
              output: out,
              errors: errors,
            ).zero?
          end
          d.check("and the error was printed") { errors.string.start_with?("Error: ") }
          d.check("under the spawn domain and the child's exit status") do
            errors.string.include?("#{Bustle::Monitor::SPAWN_EXIT_ERROR_QUARK} 1 ")
          end
        end
      end
    end

    StringIO.new.then do |out|
      StringIO.new.then do |errors|
        d.check("a log that cannot be opened at all exits 1") do
          Bustle::PcapCli.run(
            [File.join(SCRATCH, "no-such-directory", "out.bustle")],
            output: out,
            errors: errors,
          ) == 1
        end
        d.check("and nothing was announced before it was known to have failed") { out.string.empty? }
        d.check("the failure itself was printed") { errors.string.include?("Failed to start dbus-monitor") }
      end
    end
  end

  d.step("bustle-pcap warns about an unparseable frame on stderr") do
    covers(20)
    Bustle::PcapCli.new(["--verbose", File.join(SCRATCH, "verbose.bustle")]).then do |cli|
      cli.send(:parse)
      cli.instance_variable_set(:@output, StringIO.new)
      StringIO.new.then do |captured|
        $stderr = captured
        begin
          cli.send(:summarise, 0, "not a marshalled message")
        ensure
          $stderr = STDERR
        end
        d.check("the warning went to stderr") { captured.string.include?(Bustle._("Warning: ")) }
        d.check("and not into the stream of message summaries") do
          cli.instance_variable_get(:@output).string.empty?
        end
      end
    end
  end

  # --- 21. the live bus monitor's stop and error mapping ---------------------

  # The monitor's own recording path needs a session bus of its own and is
  # driven end to end by test/drive_recording.rb, which is where component 21
  # is claimed. What is driven here is the part of it a session bus cannot
  # reach: the exit statuses pkexec hands back from a system-bus recording,
  # and a Stop whose subprocess refuses to die.
  d.step("a Stop that the subprocess ignores still reports itself stopped") do
    status = nil
    File.join(SCRATCH, "unkillable.bustle").then do |path|
      Bustle::Monitor.new(target: Bustle::Monitor::SESSION_BUS, filename: path).then do |monitor|
        # A child that ignores SIGTERM and writes nothing: a privileged
        # dbus-monitor behind pkexec cannot be signalled by this process
        # either, which is the case upstream's two-second timeout and closed
        # pipe exist for.
        monitor.define_singleton_method(:argv) { ["sh", "-c", "trap '' TERM; while :; do sleep 1; done"] }
        monitor.signal_connect(Bustle::Monitor::STOPPED) { |domain, code, _message| status = [domain, code] }
        monitor.start
        d.check("the recording started") { !monitor.stopped? }
        monitor.stop
        d.check("pump stops pumping once Stop has closed the pipe") { monitor.pump == false }
        d.check("stopped arrived without waiting for the child") { monitor.stopped? }
        d.check("and arrived as the cancellation the recorder swallows") do
          status == [Bustle::Monitor::IO_ERROR_QUARK, Bustle::Monitor::IO_ERROR_CANCELLED]
        end
      end
    end
  end

  d.step("the pkexec exit statuses map onto upstream's three errors") do
    # report_exit reads a Process::Status; a stand-in with the exit status in
    # it drives all three branches without a polkit prompt.
    reported = lambda do |exitstatus|
      [].tap do |seen|
        Bustle::Monitor.new(target: Bustle::Monitor::SYSTEM_BUS, filename: File.join(SCRATCH, "exit.bustle"))
                       .then do |monitor|
          monitor.signal_connect(Bustle::Monitor::STOPPED) { |*emitted| seen.replace(emitted) }
          monitor.send(:report_exit, status_for(exitstatus))
        end
      end
    end

    d.check("126, a dismissed authorisation dialog, is a cancellation") do
      reported.call(126) ==
        [Bustle::Monitor::IO_ERROR_QUARK, Bustle::Monitor::IO_ERROR_CANCELLED,
         "User dismissed polkit authorization dialog"
]
    end
    d.check("127, a refused authorisation, is a permission error") do
      reported.call(127) ==
        [Bustle::Monitor::IO_ERROR_QUARK, Bustle::Monitor::IO_ERROR_PERMISSION_DENIED,
         "Not authorized to monitor system bus"
]
    end
    d.check("0, the bus itself going away, is a cancellation") do
      reported.call(0) ==
        [Bustle::Monitor::IO_ERROR_QUARK, Bustle::Monitor::IO_ERROR_CANCELLED,
         "dbus-monitor exited cleanly"
]
    end
    d.check("anything else carries the spawn domain and the child's status") do
      reported.call(1) ==
        [Bustle::Monitor::SPAWN_EXIT_ERROR_QUARK, 1,
         "Failed to start dbus-monitor: Child process exited with code 1"
]
    end
  end

  d.step("closing the authorisation dialog is silent, and a refusal is not") do
    outcome = lambda do |exitstatus|
      {errors: [], finished: []}.tap do |seen|
        Bustle::Recorder.new(
          target:      Bustle::Monitor::SYSTEM_BUS,
          on_progress: ->(_count, _result) { nil },
          on_finished: ->(path, recorded) { seen[:finished] << [path, recorded] },
          on_error:    ->(message) { seen[:errors] << message },
        ).then do |recorder|
          recorder.monitor.signal_connect(Bustle::Monitor::STOPPED) do |domain, code, message|
            recorder.send(
              :conclude,
              domain,
              code,
              message,
            )
          end
          recorder.monitor.send(:report_exit, status_for(exitstatus))
        end
      end
    end

    d.check("a dismissed polkit dialog reaches no error bar") { outcome.call(126).fetch(:errors).empty? }
    d.check("and still finishes the recording") { outcome.call(126).fetch(:finished).length == 1 }
    d.check("a refused authorisation does reach the error bar") do
      outcome.call(127).fetch(:errors) == ["Not authorized to monitor system bus"]
    end
    d.check("so does a dbus-monitor that would not start") do
      outcome.call(1).fetch(:errors) ==
        ["Failed to start dbus-monitor: Child process exited with code 1"]
    end
  end

  # --- 22. data files and the message catalogue -----------------------------

  d.step("the data files and the catalogue are where the app looks for them") do
    covers(22)
    d.check("the desktop entry is shipped") do
      File.exist?(File.join(ROOT, "data/org.rubygtkproject.Bustle.desktop"))
    end
    d.check("the AppStream metainfo is shipped") do
      File.exist?(File.join(ROOT, "data/org.rubygtkproject.Bustle.appdata.xml"))
    end
    d.check("the icon the window and the about dialog ask for exists") do
      File.exist?(File.join(ROOT, "data/icons/hicolor/scalable/apps/#{Bustle::AboutDialog::LOGO_ICON_NAME}.svg"))
    end
    d.check("the welcome page's symbolic icon exists") do
      File.exist?(File.join(ROOT, "data/icons/hicolor/scalable/apps/#{Bustle::WelcomePage::ICON_NAME}.svg"))
    end
    d.check("LINGUAS names the catalogues") { Bustle::Translation.languages == ["en"] }
    d.check("the en catalogue parses and carries upstream's typographic quotes") do
      Bustle::Translation.send(:load_catalogue, "en").fetch("Could not read \'%s\'") ==
        "Could not read \u2018%s\u2019"
    end
    d.check("a known msgid comes back translated or unchanged") do
      Bustle._("Welcome to Bustle") == "Welcome to Bustle"
    end
    d.check("an unknown msgid comes back as itself") do
      Bustle._("no such msgid in any catalogue") == "no such msgid in any catalogue"
    end
  end

  d.step("the markup builder escapes what the diagram and details pane put in labels") do
    covers(9)
    d.check("ampersands and brackets are escaped") do
      Bustle::Marquee.escape("a & b <c> 'd'").to_markup == "a &amp; b &lt;c&gt; &apos;d&apos;"
    end
    d.check("escaped text reads back as the original") do
      Bustle::Marquee.escape("a & b <c>").to_s == "a & b <c>"
    end
    d.check("a member with no interface is apologised for") do
      Bustle::Marquee.format_member(nil, "Ping").to_s.include?("(no interface)")
    end
    d.check("a member with an interface is dotted and bold") do
      Bustle::Marquee.format_member("org.example.Iface", "Ping").to_markup ==
        "org.example.Iface.<b>Ping</b>"
    end
  end

  d.step("the argument formatter renders what the details pane shows") do
    covers(9)
    bare = ->(signature, value) do
      Bustle::VariantFormatter.format_variant(
        Bustle::VariantFormatter::BARE,
        Bustle::Types::Variant.new(signature: signature, value: value),
      )
    end
    d.check("a string is quoted") { bare.call("s", "hi") == '"hi"' }
    d.check("a boolean is spelled out, Haskell style") { bare.call("b", true) == "True" }
    d.check("a dictionary renders as pairs") do
      bare.call("a{sv}", [["k", Bustle::Types::Variant.new(signature: "i", value: 7)]]) ==
        '{"k": <@i 7>}'
    end
    d.check("a signature splits into its types") do
      Bustle::VariantFormatter.split_signature("sia{sv}") == ["s", "i", "a{sv}"]
    end
  end

  # --- what the run covered -------------------------------------------------

  d.step("this script covered 21 of the 22 components in the inventory") do
    # Component 21, the live bus monitor, is driven by test/drive_recording.rb
    # and claimed there. This script cannot know whether that one ran, so it
    # does not claim it: test/drive_all.rb runs both and sums what they
    # covered.
    puts "    components covered: #{COVERED.sort.join(", ")}"
    puts "DRIVE COVERED #{COVERED.sort.join(",")}"
    d.check("every component but the live bus monitor was exercised") do
      COVERED.sort == ((1..22).to_a - [21])
    end
  end
end
