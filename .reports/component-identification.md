# Component identification — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` (Bustle 0.7.x, Haskell + gtk2hs, GTK 3) |
| Port | `ruby` @ `04031bc` (Ruby GTK4 + Libadwaita) |
| Upstream declarative UI | `data/bustle.ui`, `data/OpenTwoDialog.ui`, `data/RecordAddressDialog.ui` |

`.reports/component-inventory.md` holds the full upstream-side inventory
(written when the `ruby` branch was three skeleton files). This document is the
*current* identification pass over both sides and supersedes that file's "State
of the `ruby` branch" section, which is now stale.

## Whole-app scan (Step 3, `component-scan.sh`)

| Axis | Upstream distinct | Port distinct | In upstream, not in port |
|---|---:|---:|---:|
| Widget types | 26 | 25 | 16 |
| Controllers | 0 | 2 | 0 |
| Non-widget GTK types | 1 | 7 | 1 |
| CSS classes | 7 | 6 | 5 |
| Signals connected | 2 | 8 | 2 |
| GActions | 0 | 1 | 0 |

Read the signal row with Step 4 in hand, not on its own. Upstream's two scanned
signals are `message-logged` and `stopped` — the two signals of
`Bustle/Monitor.hs`, the live recorder — and **both are missing**, because the
port has no recorder at all. Everything else upstream connects is a
`GtkMenuItem::activate` or a GTK3 `*-event` in Haskell source the scanner
cannot see, so the "8 vs 2" is an artifact, not a win.

Most of the 16 missing widget types are GTK3 widgets with no GTK4 counterpart
and are correspondences, not gaps (per `component-parity` Step 3):
`Gtk.Layout` → `Gtk::DrawingArea`, `Gtk.InfoBar` → `Adwaita::Banner`,
`Gtk.Menu`/`Gtk.MenuItem`/`Gtk.ImageMenuItem`/`Gtk.CheckMenuItem`/`Gtk.SeparatorMenuItem`
→ `Gio::Menu` + `Gio::SimpleAction`, `Gtk.FileChooserButton`/`Gtk.Dialog` →
`Gtk::FileDialog`/`Adwaita::Window`, `Gtk.Table`/`Gtk.Grid` →
`Adwaita::PreferencesGroup`, `Gtk.ButtonBox` → header-bar packing,
`Gtk.HeaderBar` → `Adwaita::HeaderBar`, `Gtk.Image` → `Adwaita::StatusPage`
`icon-name`, `Gtk.Window` → `Adwaita::ApplicationWindow`.

**`Gtk.Entry` is a real absence**: its only upstream instance is
`recordAddressEntry` in `data/RecordAddressDialog.ui`, and that dialog has no
port file.

Missing CSS classes: `destructive-action` is a real absence (upstream's
`headerStop`, which the port has no button for). `image-button`,
`text-button`, `title` and `subtitle` are GTK3 header-bar idioms subsumed by
`Adwaita::HeaderBar` + `Adwaita::WindowTitle` — correspondences.

## Unit list and file mapping

The unit is the Haskell module plus whichever `data/*.ui` objects it pulls out
by id (upstream has no named templates; `builderGetObject` by id is the join).

| # | Unit | Upstream | Port |
|---:|---|---|---|
| 1 | CLI | `Bustle.hs` | `lib/bustle/main.rb` |
| 2 | application | `Bustle/UI.hs` (`uiMain`/`mainB`), `Bustle/Application/Monad.hs` | `lib/bustle/application.rb` |
| 3 | main window | `Bustle/UI.hs` + `bustle.ui`▸`diagramWindow` | `lib/bustle/window.rb` |
| 4 | header bars | `bustle.ui`▸`header`,`headerPaned`,`sidebarHeader` | `lib/bustle/header_bar.rb` |
| 5 | menus / actions / accels | `bustle.ui`▸`recordMenu`,`openMenu`,`filterStatsEtc` | `lib/bustle/menus.rb` |
| 6 | welcome page | `bustle.ui`▸`InstructionsPage` | `lib/bustle/welcome_page.rb` |
| 7 | please-hold page | `bustle.ui`▸`PleaseHoldPage` | `lib/bustle/please_hold_page.rb` |
| 8 | error bar | `bustle.ui`▸`errorBar` | `lib/bustle/error_bar.rb` |
| 9 | canvas | `Bustle/UI/Canvas.hs` + `bustle.ui`▸`diagramLayout` | `lib/bustle/canvas.rb` |
| 10 | details view | `Bustle/UI/DetailsView.hs` + `bustle.ui`▸`detailsGrid` | `lib/bustle/details_view.rb` |
| 11 | statistics pane | `Bustle/StatisticsPane.hs` + `bustle.ui`▸`sidebarStack` | `lib/bustle/statistics_pane.rb` |
| 12 | filter dialog | `Bustle/UI/FilterDialog.hs` | `lib/bustle/filter_dialog.rb` |
| 13 | open-pair dialog | `Bustle/UI/OpenTwoDialog.hs` + `OpenTwoDialog.ui` | `lib/bustle/open_two_dialog.rb` |
| 14 | about dialog | `Bustle/UI/AboutDialog.hs` | `lib/bustle/about_dialog.rb` |
| 15 | open dialog | `Bustle/UI.hs`▸`showOpenDialog` | `lib/bustle/open_dialog.rb` |
| 16 | PDF save dialog | `Bustle/UI.hs`▸`saveToPDFDialogue` | `lib/bustle/pdf_export.rb` |
| 17 | batch modes | `Bustle/Noninteractive.hs` | `lib/bustle/noninteractive.rb` |
| 18 | **record-address dialog** | `Bustle/UI/RecordAddressDialog.hs` + `RecordAddressDialog.ui` | **— none** |
| 19 | **recorder** | `Bustle/UI/Recorder.hs` (`recorderRun`, `recorderChooseFile`) | **— none** |
| 20 | **monitor** | `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` | **— none** |
| 21 | **save / prompt-to-save** | `Bustle/UI.hs`▸`showSaveDialog`, `promptToSave` | **— none** |
| 22 | **`bustle-pcap` CLI** | `c-sources/bustle-pcap.c` | **— none** |

Backend modules (`Types`, `Loader`, `Loader/Pcap`, `Renderer`, `Diagram`,
`Regions`, `Stats`, `Marquee`, `VariantFormatter`, `Missing`, `Util`,
`Translation`) all have a port file of the same name. 17 of 22 UI/CLI units
have a counterpart; **5 have none**, and unit 5 is only half built.

## Per-unit inventory, upstream side

### `bustle.ui`▸`diagramWindow` + `Bustle/UI.hs` — the only window

| Widget | × | id / CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | `diagramWindow` | `destroy`→`maybeQuit`, `delete-event`→`promptToSave` | 900×700 |
| `Gtk.Paned` | 3 | `headerPaned`, `sidebarPaned`, `contentPaned` | — | `headerPaned` position bound bidirectionally to `sidebarPaned` |
| `Gtk.HeaderBar` | 2 | `header`, `sidebarHeader` | — | `GtkSizeGroup` ties `sidebarHeader` to `sidebarStack` |
| `Gtk.StackSwitcher` | 1 | title of `sidebarHeader` | — | Frequencies/Durations/Sizes |
| `Gtk.MenuButton` | 3 | `headerRecord` (`text-button image-button suggested-action`, 100px, `_Record`, `media-record-symbolic`), `headerOpen` (`image-button`), hamburger (`image-button`, `open-menu-symbolic`) | — | popups `recordMenu`, `openMenu`, `filterStatsEtc` |
| `Gtk.Button` | 3 | `headerStop` (`destructive-action`, `_Stop`), `headerExport` (`image-button`, `document-send-symbolic`, tooltip "Export as PDF", insensitive), `headerSave` (`image-button`, `document-save-symbolic`, tooltip "Save", insensitive, `Ctrl+S`) | `clicked` | Record+Open hide while recording; Stop shows and takes focus |
| `Gtk.Spinner` | 1 | `headerSpinner` | — | started/stopped around recording |
| `Gtk.Label` | 2 | `headerTitle` (`title`), `headerSubtitle` (`subtitle`) | — | markup; subtitle is `Logged <b>%u</b> messages` while recording |
| `Gtk.Stack` | 1 | `diagramOrNot` | — | `InstructionsPage`/`PleaseHoldPage`/`CanvasPage` |
| `Gtk.SizeGroup` | 1 | — | — | not a widget |

Accelerators (all `GtkMenuItem::activate` + `<accelerator>`, no GAction
anywhere): `Ctrl+F` filter, `F9` statistics, `Ctrl+O` open, `Ctrl+E` record
session bus, `Ctrl+Y` record system bus, `Ctrl+A` record address, `Ctrl+S` save
log.

### `bustle.ui`▸`recordMenu`, `openMenu`, `filterStatsEtc`

| Menu | Items |
|---|---|
| `recordMenu` | `Record S_ession Bus` (Ctrl+E), `Record S_ystem Bus` (Ctrl+Y), `Record _Address…` (Ctrl+A) |
| `openMenu` | `gtk-open` (Ctrl+O), `O_pen a Pair of Logs…` |
| `filterStatsEtc` | `_Filter Visible Services…` (Ctrl+F, insensitive until a log loads), `_Statistics` check item (F9, same), separator, `gtk-about` |

### `RecordAddressDialog.ui` + `Bustle/UI/RecordAddressDialog.hs`

| Widget | × | id | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Dialog` | 1 | `recordAddressDialog` | `response` | title "Record Address", destroyed on response |
| `Gtk.Label` | 1 | — | — | "Address:" |
| `Gtk.Entry` | 1 | `recordAddressEntry` | `changed` → Record sensitivity | placeholder `e.g. unix:abstract=/tmp/dbus-E5RlEB5Tzu,guid= b1c1921b62283b7b612b57305b20cc28` (comment: "Just translate the 'e.g.'") |
| `Gtk.Button` | 2 | `recordAddressCancel`, `recordAddressRecord` | `clicked` | `_Record` insensitive while the entry is empty |

### `Bustle/UI/Recorder.hs` — the recording flow

Not a `.ui` file; a sequence. `recorderRun` opens a `Bustle.Monitor` on a bus
(or address), writes pcap frames to a temp file under `getCacheDir`, pumps
`message-logged` through `processSome` into the canvas, scrolls to the bottom,
counts messages into the header subtitle, and on `stopped` presents
`recorderChooseFile` — a `GtkFileChooserDialog` in Save mode with
`gtk-cancel`/`gtk-new` — then moves the temp file to the chosen path. On
failure it warns `You might want to manually recover the log from the
temporary file at \"%s\".`

### `Bustle/UI.hs`▸`promptToSave` / `showSaveDialog`

`GtkMessageDialog` (warning) — `Save log '%s' before closing?` /
`If you don't save, this log will be lost forever.`, buttons
`Close _Without Saving` / Cancel / Save — wired to `delete-event`; plus a Save
`GtkFileChooserDialog` and the `Couldn't save log: ` error path.

## Port side, as built

| Port file | Root widget | CSS applied | Behaviour wired |
|---|---|---|---|
| `window.rb` | `Adwaita::ApplicationWindow` → `Adwaita::ToolbarView` → `Gtk::Box` → `Gtk::Stack` → `Gtk::Paned`(h) → `Gtk::Paned`(v) | — | 6 window actions |
| `header_bar.rb` | `Adwaita::HeaderBar` ×2, `Adwaita::WindowTitle`, `Gtk::StackSwitcher`, `Gtk::MenuButton` ×2, `Gtk::Button` ×1 | — | menu models + `win.export-pdf` |
| `menus.rb` | `Gio::Menu` ×4, `Gio::SimpleAction` ×6 | — | `open`, `open-pair`, `filter`, `export-pdf`, `about`, `statistics` |
| `welcome_page.rb` | `Adwaita::StatusPage` + markup `Gtk::Label` | `dim-label` | — |
| `please_hold_page.rb` | `Adwaita::StatusPage` + `Gtk::Spinner` | — | built, **never shown** |
| `error_bar.rb` | `Gtk::Box` → `Adwaita::Banner` + `Gtk::Label` | `dim-label` | `button-clicked` |
| `canvas.rb` | `Gtk::ScrolledWindow` → `Gtk::DrawingArea` | — | `GestureClick` `pressed`, `EventControllerKey` `key-pressed` |
| `details_view.rb` | `Gtk::Box` → `Adwaita::PreferencesGroup` (5 `Adwaita::ActionRow`) + `Gtk::TextView` | `heading`, `property` | `update(message)` |
| `statistics_pane.rb` | `Gtk::Stack` → 3 `Gtk::ScrolledWindow` → 3 `Gtk::ColumnView` (10 columns, `SignalListItemFactory`) | `data-table`, `dim-label` | setup/bind |
| `filter_dialog.rb` | `Adwaita::Window` → `Adwaita::ToolbarView` → `Gtk::ListBox` of `Adwaita::ActionRow` + `Gtk::CheckButton` | `boxed-list`, `suggested-action` | `clicked`, `close-request` |
| `open_two_dialog.rb` | `Adwaita::Window` → `Adwaita::PreferencesGroup` (2 `Adwaita::ActionRow` + buttons) | `suggested-action` | `clicked` ×4 |
| `about_dialog.rb` | `Gtk::AboutDialog` | — | — |
| `open_dialog.rb`, `pdf_export.rb` | `Gtk::FileDialog` | — | async callback |

Repeaters: `statistics_pane` builds one row per `Stats::*Info`;
`filter_dialog` one row per participant. Conditional: `details_view`'s
destination row hides for a broadcast signal; `error_bar`'s details label
hides when there are none.
