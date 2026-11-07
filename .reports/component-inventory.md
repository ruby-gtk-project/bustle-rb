# Bustle component inventory

Survey of upstream (Haskell, `origin/master`) user-facing components against
the Ruby port on `ruby`. Upstream has no `.blp`; its one declarative file is
the GTK3 GtkBuilder `data/bustle.ui`, referenced by `Bustle/UI.hs`. There is
no GSettings schema anywhere in this app (Bustle keeps no persisted
preferences) and no shortcuts window.

Every component below already exists in `lib/` and carries a `# Ported
from upstream's ...` header comment naming its source. This is a survey, not
a gap list — recorded here so a later `component-parity` pass has a per-file
map to check widget/CSS/signal counts against, not just file existence.

| # | Upstream file(s) | → `lib/*.rb` | Kind | Present |
|---|---|---|---|---|
| 1 | `Bustle.hs` | `lib/bustle/main.rb` | CLI entry point / argument dispatch | ✅ |
| 2 | `Bustle/UI.hs` (`uiMain`, `mainB`) | `lib/bustle/application.rb` | `Adw.Application` subclass: app-level actions, window accounting | ✅ |
| 3 | `Bustle/UI.hs` (`diagramWindow` + rest of the window logic) + `data/bustle.ui` `diagramWindow`/`headerPaned`/`contentPaned`/`sidebarPaned`/`diagramOrNot` stack | `lib/bustle/window.rb` | Main window: assembles header bar, error bar, welcome/please-hold/canvas stack pages, statistics pane, details view | ✅ |
| 4 | `data/bustle.ui` `header`, `sidebarHeader`, `headerPaned`, `headerRecord`, `headerStop`, `headerOpen`, `headerSpinner`, `headerTitle`, `headerSubtitle`, `headerExport`, `headerSave` | `lib/bustle/header_bar.rb` | Header bar: title/subtitle, record/stop/open/save/export controls, spinner | ✅ |
| 5 | `data/bustle.ui` `filterStatsEtc`, `openMenu`, `recordMenu` (`GtkMenu`s) + the actions/accelerators they fire in `Bustle/UI.hs` | `lib/bustle/menus.rb` | Window actions (`win.*`) and their keyboard accelerators, replacing the three old-style `GtkMenu`s with `Gio::Menu`/popovers | ✅ |
| 6 | `data/bustle.ui` `errorBar`/`errorBarTitle`/`errorBarDetails` (`GtkInfoBar`) | `lib/bustle/error_bar.rb` | Inline error banner shown over the canvas | ✅ |
| 7 | `data/bustle.ui` `InstructionsPage` stack page | `lib/bustle/welcome_page.rb` | Empty-state / welcome page shown before any log is loaded | ✅ |
| 8 | `data/bustle.ui` `PleaseHoldPage` stack page | `lib/bustle/please_hold_page.rb` | Loading placeholder shown while a log is being parsed | ✅ |
| 9 | `Bustle/UI/Canvas.hs` + `data/bustle.ui` `diagramLayout`/`scrolledwindow1` | `lib/bustle/canvas.rb` | The diagram drawing surface: scrolling, selection, click/keyboard navigation | ✅ |
| 10 | `Bustle/Diagram.hs` | `lib/bustle/diagram.rb` | Diagram model: the flat array of drawable shapes the canvas renders | ✅ |
| 11 | `Bustle/Renderer.hs` | `lib/bustle/renderer.rb` | Converts a parsed log into a `Diagram` | ✅ |
| 12 | `Bustle/Regions.hs` | `lib/bustle/regions.rb` | Selection zipper backing canvas row selection | ✅ |
| 13 | `Bustle/UI/DetailsView.hs` + `data/bustle.ui` `detailsGrid` and its `detailsType`/`detailsPath`/`detailsMember`/`detailsArguments`/`detailsSender`/`detailsDestination*` children | `lib/bustle/details_view.rb` | Detail pane for the selected message/method-call/signal/error row | ✅ |
| 14 | `Bustle/StatisticsPane.hs` + `data/bustle.ui` `sidebarPaned`/`sidebarStack`/`frequencySW`/`durationSW`/`sizeSW` | `lib/bustle/statistics_pane.rb` | Sidebar statistics tables (frequency, duration, size) | ✅ |
| 15 | `Bustle/Stats.hs` | `lib/bustle/stats.rb` | Statistics model computed from a loaded log | ✅ |
| 16 | `Bustle/UI/FilterDialog.hs` | `lib/bustle/filter_dialog.rb` | "Filter Visible Services…" dialog | ✅ |
| 17 | `Bustle/UI/AboutDialog.hs` | `lib/bustle/about_dialog.rb` | About dialog (name, version, authors, license, logo) | ✅ |
| 18 | `Bustle/UI.hs` (`showOpenDialog`) | `lib/bustle/open_dialog.rb` | "Open a log" native file chooser | ✅ |
| 19 | `Bustle/UI/OpenTwoDialog.hs` + `data/OpenTwoDialog.ui` | `lib/bustle/open_two_dialog.rb` | "Open two logs to merge" dialog | ✅ |
| 20 | `Bustle/UI/RecordAddressDialog.hs` + `data/RecordAddressDialog.ui` | `lib/bustle/record_address_dialog.rb` | "Record a custom bus address" dialog (reachable from `recordMenu`'s `recordAddress` item) | ✅ |
| 21 | `Bustle/UI/Recorder.hs` | `lib/bustle/recorder.rb` | Recording session controller: start/stop, save-as chooser (shared with `headerSave`) | ✅ |
| 22 | `Bustle/Monitor.hs` + `c-sources/pcap-monitor.{c,h}` | `lib/bustle/monitor.rb` | GObject/FFI binding that drives `dbus-monitor`/pcap capture | ✅ |
| 23 | `Bustle/UI.hs` (`saveToPDFDialogue`) | `lib/bustle/pdf_export.rb` | "Export to PDF" save chooser + Cairo PDF render of the current diagram | ✅ |
| 24 | `Bustle/Loader.hs` | `lib/bustle/loader.rb` | Top-level log loading/filtering entry point | ✅ |
| 25 | `Bustle/Loader/Pcap.hs` | `lib/bustle/pcap_loader.rb` | Parses captured pcap data into the message model | ✅ |
| 26 | `Bustle/Types.hs` | `lib/bustle/types.rb` | Core domain model: bus names, members, messages, name-owner changes, timestamps | ✅ |
| 27 | `Bustle/VariantFormatter.hs` | `lib/bustle/variant_formatter.rb` | Formats D-Bus variant values for display in the details pane | ✅ |
| 28 | `Bustle/Marquee.hs` | `lib/bustle/marquee.rb` | Lightweight markup builder used by several widgets' labels | ✅ |
| 29 | `Bustle/Util.hs` | `lib/bustle/util.rb` | Warning channel / shared helpers | ✅ |
| 30 | `Bustle/Missing.hs` | `lib/bustle/missing.rb` | One-function FFI shim | ✅ |
| 31 | `Bustle/Translation.hs`, `src-hgettext/Bustle/Translation.hs`, `src-no-hgettext/Bustle/Translation.hs`, `GetText.hs` | `lib/bustle/translation.rb` | Message-catalogue lookup (gettext) | ✅ |
| 32 | `Bustle/Noninteractive.hs` | `lib/bustle/noninteractive.rb` | Batch/headless modes: dump, pcap-to-bustle conversion, etc. | ✅ |
| 33 | `c-sources/bustle-pcap.c` (+ `config.h`) | `lib/bustle/pcap_cli.rb` | Standalone `bustle-pcap` CLI binary and its "Help Options:" section | ✅ |
| 34 | `data/org.freedesktop.Bustle.desktop.in` | `data/org.rubygtkproject.Bustle.desktop.in` (+ generated `.desktop`) | Desktop launcher entry | ✅ |
| 35 | `data/org.freedesktop.Bustle.appdata.xml.in` | `data/org.rubygtkproject.Bustle.appdata.xml.in` (+ generated `.appdata.xml`) | AppStream metadata (summary, description, screenshots) | ✅ |
| 36 | `data/icons/hicolor/**` | `data/icons/hicolor/**` | App icon set (hicolor theme, symbolic variant) | ✅ |
| 37 | `po/messages.pot`, `po/LINGUAS`, `po/en.po` | `po/messages.pot`, `po/LINGUAS`, `po/en.po` | Translation catalogue (upstream ships only `en`; no other locales to port) | ✅ |
| 38 | `Bustle/Application/Monad.hs` | — (no port file) | Internal `Reader`/`State`/`Except` monad stack scaffolding the Haskell app; not a UI component and has no Ruby equivalent — Ruby state is held directly on `Window`/`Application` instances | N/A — infra, not a component |

## Notes for a follow-on `component-parity` pass

- `lib/bustle/menus.rb` replaces three legacy `GtkMenu`s (`filterStatsEtc`,
  `openMenu`, `recordMenu`) with `win.*` actions and
  `Gtk::Application#set_accels_for_action`. Parity check should confirm every
  accelerator upstream's menu items advertise (`Ctrl+F` filter, `F9`
  statistics, etc. — read off `data/bustle.ui`'s `<accelerator>` elements) is
  present in `Menus::WINDOW_ACTIONS`/`STATISTICS_ACCELS`, not just that the
  actions exist.
- `data/bustle.ui`'s `GtkMenu`/`GtkMenuItem`/`GtkCheckMenuItem` objects
  (`filter`, `statistics`, `about`, `open`, `openTwo`, `recordSession`,
  `recordSystem`, `recordAddress`) are the per-item unit for that accelerator
  check; they are not separate components from `lib/bustle/menus.rb`.
- No upstream GSettings schema, no shortcuts window, no additional `.ui`
  files beyond `data/bustle.ui`, `data/OpenTwoDialog.ui`,
  `data/RecordAddressDialog.ui` — all three are accounted for above.
- `Test/*.hs` and `Test/data/*` are upstream's own Haskell test suite, not a
  user-facing component; left out of this inventory (would be covered by a
  `test-parity` pass instead).
