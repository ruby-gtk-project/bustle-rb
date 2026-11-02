# bustle-rb — upstream component inventory

Upstream: `origin/master` (Bustle 0.7.x, **Haskell** + gtk2hs, GTK **3**, three
GtkBuilder `.ui` files, one C GObject for the pcap monitor).
Port target: `ruby` branch, Ruby GTK4 + Libadwaita, house style per
`.claude/skills/ruby-gtk`.

What Bustle is: it records D-Bus traffic (session bus, system bus, or an
arbitrary address) into a pcap-format `.bustle` log, or loads one off disk, and
draws it as a sequence diagram — one column per bus name, one row per message —
with a details pane for the selected message, a statistics sidebar, a service
filter, and PDF export.

## State of the `ruby` branch

Three files, skeleton only:

| File | What it is |
|---|---|
| `lib/bustle.rb` | one `require_relative` |
| `lib/bustle/application.rb` | `Gtk::Application` + `Adwaita::ApplicationWindow` + `Adwaita::StatusPage` saying the port is unwritten |
| `lib/bustle/rb/version.rb` | version constant |

No canvas, no loader, no recorder, no dialogs, no stats, no details view.
Everything below except `application.rb` and `version.rb` is missing.

## Upstream unit list

Upstream has no `template`/named-root blueprint; each `.ui` is a bag of
top-level `<object>`s pulled out by id from Haskell (`builderGetObject`). So the
unit boundary is **the Haskell module**, and `data/bustle.ui` is split across
four of them (`UI.hs`, `Canvas.hs`, `DetailsView.hs`, `StatisticsPane.hs`) — its
rows are unioned into whichever module grabs them by id.

## Windows and pages

### `Bustle/UI.hs` + `data/bustle.ui` (`diagramWindow`) — the only window

900×700 `GtkWindow`, icon `org.freedesktop.Bustle`, titlebar is a `GtkPaned`
(`headerPaned`) so the sidebar header lines up with the sidebar; its `position`
is bidirectionally bound to `sidebarPaned`. One window per log; the app is
multi-window (`windows` counter, quit on last close).

| Widget | × | id / CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` | 1 | `diagramWindow` | `destroy` → `maybeQuit`, `delete-event` → `promptToSave` | title/subtitle set from the log path |
| `Gtk.Paned` | 1 | `headerPaned` | — | titlebar; holds both header bars |
| `Gtk.HeaderBar` | 2 | `sidebarHeader` (hidden until stats on), `header` | — | `GtkSizeGroup` ties `sidebarHeader` to `sidebarStack` |
| `Gtk.StackSwitcher` | 1 | title of `sidebarHeader`, drives `sidebarStack` | — | Frequency / Duration / Size |
| `Gtk.MenuButton` | 3 | `headerRecord` (`text-button image-button suggested-action`, popup `recordMenu`), `headerOpen` (`image-button`, popup `openMenu`), unnamed (`image-button`, `open-menu-symbolic`, popup `filterStatsEtc`) | — | Record is 100px wide, label `_Record` + `media-record-symbolic` |
| `Gtk.Button` | 3 | `headerStop` (`destructive-action`, `_Stop`), `headerExport` (`image-button`, `document-send-symbolic`, tooltip "Export as PDF", insensitive), `headerSave` (`image-button`, `document-save-symbolic`, tooltip "Save", insensitive, `Ctrl+S`) | `clicked` → stop monitor / `saveToPDFDialogue` / `showSaveDialog` | Record+Open hidden while recording, Stop shown and focused |
| `Gtk.Spinner` | 1 | `headerSpinner` | — | started/stopped around recording |
| `Gtk.Label` | 2 | `headerTitle` (`title`), `headerSubtitle` (`subtitle`) | — | markup; subtitle is "Logged **n** messages" while recording |
| `Gtk.Stack` | 1 | `diagramOrNot` | — | pages `InstructionsPage`, `PleaseHoldPage`, `CanvasPage` |
| `Gtk.Paned` | 2 | `sidebarPaned`, `contentPaned` | — | stats | (canvas | details) |
| `Gtk.SizeGroup` | 1 | — | — | `sidebarHeader` + `sidebarStack` |

Actions, accelerators: no `GAction` anywhere — upstream explicitly notes it
would need GApplication/GMenu bindings it does not have. Everything is a
`GtkMenuItem::activate` plus a `<accelerator>`: `Ctrl+F` filter, `F9`
statistics, `Ctrl+S` save, `Ctrl+O` open. The port should install real
`Gio::SimpleAction`s on the window and an `Adwaita::AboutDialog`/menu model.

Window title logic (`logWindowTitle`/`logTitle`): recorded logs get `*name`,
single logs `name` + directory subtitle, paired logs `a & b`.

### Welcome / instructions page — `diagramOrNot` ▸ `InstructionsPage`

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Box` | 1 | — | vertical, centred, spacing 12 |
| `Gtk.Image` | 1 | `dim-label` | 256px `org.freedesktop.Bustle-symbolic` |
| `Gtk.Label` | 2 | `dim-label` | "Welcome to Bustle" (bold, scale 2); "Start recording D-Bus activity with the **Record** button above / You can also run *dbus-monitor --pcap* from the command line" |

Natural `Adwaita::StatusPage` in the port.

### Please-hold page — `diagramOrNot` ▸ `PleaseHoldPage`

One `Gtk.Label` (`label5`), markup "**Waiting for D-Bus traffic; please hold…**".
Shown by `startRecording`, left for `CanvasPage` on the first rendered message.

### Error bar — `data/bustle.ui` ▸ `errorBar`

`Gtk.InfoBar` + `GtkButtonBox` close button, `errorBarTitle` (bold markup) and
`errorBarDetails` (small markup, hidden when there is no body); `response`
hides it. Every failure in the app lands here: unreadable log, failed save,
failed PDF export, monitor error (except `IoErrorCancelled`, filtered). In the
port this is an `Adwaita::ToastOverlay`/`Adwaita::Banner` decision — a banner
keeps the two-line title+details shape.

## Content widgets

### `Bustle/UI/Canvas.hs` + `data/bustle.ui` ▸ `diagramLayout` — the diagram

`Gtk.Layout` inside `scrolledwindow1`, drawn by hand with Cairo. Step
increments on both adjustments set to `eventHeight`.

| Facet | Detail |
|---|---|
| Signals | `draw` → `canvasDraw`; `button-press-event` (left button → select region under y, grab focus); two `key-press-event` handlers: Left/Right = h-step, space = v-page, Up/Down/Home/End = move region selection |
| Behaviour | selection highlight drawn as an extra `Highlight` shape; `canvasClampAroundSelection` scrolls the selection into view on an idle; `canvasScrollToBottom` during recording; h-scroll centred on `rrCentreOffset` |
| Callback | `selectionChangedCb` → `updateDetailsView` (shows/hides the details grid) |

`Gtk.Layout` does not exist in GTK4: the port needs `Gtk::DrawingArea` in a
`Gtk::ScrolledWindow` (or a `Gtk::Fixed`), a `Gtk::GestureClick`, a
`Gtk::EventControllerKey`, and explicit `set_size_request`.

### `Bustle/UI/DetailsView.hs` + `data/bustle.ui` ▸ `detailsGrid` — message details

| Widget | × | id | Notes |
|---|---:|---|---|
| `Gtk.Grid` | 1 | `detailsGrid` | hidden when nothing is selected |
| `Gtk.Label` | 6 | captions Type/Path/Member/Arguments/Sender, `detailsDestinationCaption` | all `dim-label`; the Destination caption and value hide for undirected signals |
| `Gtk.Label` | 4 | `detailsPath`, `detailsMember` (markup), `detailsSender`, `detailsDestination` | selectable value labels |
| `Gtk.Stack` | 1 | `detailsType` | 5 pages: `methodCall`/`methodReturn`/`error`/`signal`/`directedSignal` with labels "Method call", "Method return", "Error", "Signal", "Directed signal" |
| `Gtk.TextView` | 1 | `detailsArguments` | in a `Gtk.ScrolledWindow`; body formatted by `VariantFormatter` |

### `Bustle/StatisticsPane.hs` + `data/bustle.ui` ▸ `sidebarStack` — statistics sidebar

Three `Gtk.ScrolledWindow`s (`frequencySW`, `durationSW`, `sizeSW`) in a
`Gtk.Stack`, each filled with a `Gtk.TreeView` + `Gtk.ListStore` built in
Haskell. Hidden at startup; shown by the `_Statistics` check item (F9), which
also reveals `sidebarHeader`.

| View | Columns |
|---|---|
| Frequency | Member (type "Method"/"Signal" + ellipsised-start member markup, 30 chars, right-aligned) · Frequency (`Gtk.CellRendererProgress`, min width 120, value scaled against the max) |
| Duration | Method · Total (`%.1f ms`) · Calls · Mean (`%.1f ms`) |
| Size | Member ("Method call"/"Method return"/"Error"/"Signal"; returns italic, errors red) · Smallest · Mean · Largest (`formatSize`) |

All three `TreeView`s are 7pt text with headers visible. In GTK4 these become
`Gtk::ColumnView` + `Gtk::SignalListItemFactory` over a
`Gtk::SortListModel`/`Gio::ListStore`, and the progress cell becomes a
`Gtk::LevelBar`/`Gtk::ProgressBar` in the factory.

## Menus

### `data/bustle.ui` ▸ `recordMenu`, `openMenu`, `filterStatsEtc`

| Menu | Items |
|---|---|
| `recordMenu` (Record button) | `Record S_ession Bus`, `Record S_ystem Bus`, `Record _Address…` |
| `openMenu` (Open button) | `gtk-open` (`open`), `O_pen a Pair of Logs…` (`openTwo`) |
| `filterStatsEtc` (hamburger) | `_Filter Visible Services…` (`Ctrl+F`, insensitive until a log is loaded), `_Statistics` check item (`F9`, insensitive until loaded), separator, `gtk-about` |

Stock `GtkImageMenuItem`s and `GtkMenu` are gone in GTK4: one `Gio::Menu`
model per button, items bound to window actions, insensitivity driven by
`action.enabled =`.

## Dialogs

| Upstream | What it is |
|---|---|
| `Bustle/UI/FilterDialog.hs` | "Filter Visible Services": `GtkDialog`, 7/8 × window width, half its height, transient, Close button; a wrapping instructions `Gtk.Label` (600px) and a `Gtk.ScrolledWindow` + headerless `Gtk.TreeView` (600×371) with a toggle column and a name column. Names are grouped per namespace and collapsed as `org.example.{Foo,Bar}`; unticked names are returned as the hidden set and the log is re-rendered through `processWithFilters` |
| `Bustle/UI/OpenTwoDialog.hs` + `data/OpenTwoDialog.ui` | "Open a Pair of Logs": `GtkDialog`, `GtkTable`, two `GtkFileChooserButton`s (`sessionBusChooser`, `systemBusChooser`) with labels "Session bus log:" / "System bus log:", Cancel + Open. Open is sensitive only when both are set (`file-set`); each chooser propagates its current folder to the other while the other is empty; hidden (not destroyed) and unselected on response |
| `Bustle/UI/RecordAddressDialog.hs` + `data/RecordAddressDialog.ui` | "Record Address": `GtkDialog`, "Address:" label + `Gtk.Entry` (`recordAddressEntry`), Cancel + `_Record`; Record sensitive only on non-empty entry (`changed`); destroyed on response |
| `Bustle/UI/AboutDialog.hs` | `GtkAboutDialog`: name "Bustle", version, comments "Someone's favourite D-Bus profiler", website, 10 authors, copyright "© 2008–2017 Will Thompson, Collabora Ltd. and contributors", LICENSE read off disk, logo `org.freedesktop.Bustle` |
| `Bustle/UI.hs` ▸ `showOpenDialog` | `GtkFileChooserDialog` open, modal, local-only, Cancel/Open → load in the initial window |
| `Bustle/UI.hs` ▸ `saveToPDFDialogue` | `GtkFileChooserDialog` save, modal, local-only, overwrite confirmation, current name `<log>.pdf`, folder defaults to the log's directory; renders the diagram to a Cairo PDF surface |
| `Bustle/UI/Recorder.hs` ▸ `recorderChooseFile` | `GtkFileChooserDialog` save used after recording, current name = temp file name, Cancel/New; moves the cache temp file to the chosen path |
| `Bustle/UI.hs` ▸ `promptToSave` | `GtkMessageDialog` warning, "Save log '%s' before closing?" / "If you don't save, this log will be lost forever.", buttons `Close _Without Saving` / Cancel / Save; `delete-event` handler |

`GtkFileChooserDialog` and `GtkFileChooserButton` are both replaced by
`Gtk::FileDialog` (async, no response ids) in GTK4; the message dialog becomes
`Adwaita::AlertDialog`.

## Backend / non-widget

| Upstream | Role |
|---|---|
| `Bustle/Types.hs` | bus names (unique vs well-known), members, messages, NOC events, `Detailed` wrapper, microseconds |
| `Bustle/Loader.hs` | `readLog`, `LoadError`, `isRelevant` |
| `Bustle/Loader/Pcap.hs` | pcap frame → D-Bus message, call/return matching by (destination, serial) |
| `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` | the live recorder: a C GObject wrapping libpcap + `dbus-monitor`-style eavesdropping, signals `message-logged` and `stopped` |
| `c-sources/bustle-pcap.c` | standalone `bustle-pcap` CLI recorder |
| `Bustle/Renderer.hs` | the whole layout engine: columns per participant, rows per message, pending-call bookkeeping, `RendererResult`, incremental `processSome`, `processWithFilters` |
| `Bustle/Diagram.hs` | `Shape` algebra (header, arc, arrow, timestamp, highlight…) and the Cairo drawing of it, plus geometry constants |
| `Bustle/Regions.hs` | y-stripe ↔ message index map and the selection cursor the canvas drives |
| `Bustle/Stats.hs` | `frequencies`, `methodTimes`, `messageSizes` |
| `Bustle/Marquee.hs` | tiny Pango-markup builder (`b`, `i`, `small`, `red`, `escape`, `formatMember`) |
| `Bustle/VariantFormatter.hs` | D-Bus variant → readable argument text |
| `Bustle/Missing.hs` | `formatSize` |
| `Bustle/Util.hs` | `warn`, `getCacheDir` |
| `Bustle/Noninteractive.hs` | `--count`, `--time`, `--dot` batch modes |
| `Bustle.hs` | CLI: `[LOGFILE…]`, `--pair SESSION SYSTEM`, `--count`, `--time`, `--dot`, `--help` |
| `Bustle/Application/Monad.hs` | the `B` reader/state monad (window count, initial window, debug flag) — not a port target; becomes ordinary instance state on the application object |
| `Bustle/Translation.hs`, `GetText.hs`, `po/` | gettext plumbing; the catalogue has exactly one language (`po/LINGUAS` = `en`, 67 msgids) |
| `data/org.freedesktop.Bustle.desktop.in`, `.appdata.xml.in`, `data/icons/…` | desktop entry (MIME `application/vnd.tcpdump.pcap`), AppStream metadata, icons |

No GSettings schema and no GResource manifest upstream — nothing to port there.
`--debug` (show shape bounds in the canvas) is the only hidden option.

## Blockers and judgement calls

1. **Live recording.** `Bustle/Monitor.hs` is a thin FFI shim over
   `c-sources/pcap-monitor.c` (~28 KB of C): it becomes a `BecomeMonitor`
   eavesdropper on the bus and writes pcap frames. There is no Ruby libpcap
   binding in this project's gemset and no Ruby equivalent of the C GObject, so
   the port either shells out to `dbus-monitor --pcap` / the upstream
   `bustle-pcap` binary and watches the file grow, or writes its own
   `BecomeMonitor` client with `ruby-dbus` plus a hand-rolled pcap writer.
   Decide before `lib/bustle/monitor.rb` is written; everything in the recording
   flow (spinner, PleaseHold page, Stop button, save prompt) depends on it.
2. **pcap parsing.** `Loader/Pcap.hs` leans on Haskell's `dbus` package to
   unmarshal wire messages. Ruby needs a marshaller of its own (or `ruby-dbus`
   internals) for both reading `.bustle` files and the live path.
3. **GTK3-only widgets.** `GtkLayout`, `GtkTreeView`/`GtkListStore`/cell
   renderers, `GtkMenu`/`GtkMenuItem`/`GtkImageMenuItem`/`GtkCheckMenuItem`,
   `GtkFileChooserButton`, `GtkFileChooserDialog`, `GtkTable`, `GtkInfoBar`,
   `GtkButtonBox` and stock items all have no GTK4 counterpart. These are
   remodellings, not transcriptions — see the per-component notes above.
4. **Paned-titlebar trick.** The bound `headerPaned`/`sidebarPaned` position is
   a GTK3 custom-titlebar idiom; under Libadwaita the honest shape is
   `Adwaita::OverlaySplitView` (or `Adwaita::NavigationSplitView`) with its own
   header bars, which changes the widget tree even though the UX survives.
5. **PDF export** needs the `cairo` gem's PDF surface plus a full port of
   `Diagram.hs`'s drawing code; it cannot land before the canvas does.
6. **Translations.** Only `po/en.po` exists upstream, so there is no real
   catalogue to carry over — just the 67 translatable strings, which must stay
   wrapped in whatever gettext call the port adopts.
