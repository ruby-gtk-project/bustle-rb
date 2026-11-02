# bustle-rb — upstream component inventory

Survey of every user-facing component on `origin/master` (Bustle 0.8.x, Haskell
+ GTK3 via `Graphics.UI.Gtk`, widget trees in GtkBuilder XML) against what the
`ruby` branch's `lib/` already carries.

Method: the `component-identification` skill. Upstream's declarative UI is three
GtkBuilder files (`data/bustle.ui`, `data/OpenTwoDialog.ui`,
`data/RecordAddressDialog.ui`) read with `builderAddFromFile`; none of them use
`<template>`, they declare top-level named objects fetched by id through
`builderGetObject`, so the unit list comes from the ids each Haskell module
grabs. There is **no GSettings schema, no GResource manifest and no blueprint**
in upstream at all — `getDataFileName "data/bustle.ui"` loads the XML off disk,
and there are no app actions or accelerator groups either (UI.hs has a comment
saying the app menu "entails binding GApplication, GtkApplication, GMenu,
GActionMap, GActionEntry, ..." and declines). Accelerators live on the
GtkMenuItems in `data/bustle.ui`.

Every upstream component below is split across a `.hs` module and a chunk of
`data/bustle.ui`; the rows are unioned per port file before comparing, as the
skill requires.

## Totals

| | Upstream | `ruby` branch |
|---|---|---|
| User-facing components | 22 | 22 present, 0 missing |
| Declarative UI files | 3 `.ui` | 0 by design (memoized builders) |
| GSettings schemas | 0 | 0 |
| GResource manifests | 0 | 0 |
| `po/LINGUAS` | `en` | `en` |
| `msgid`s in `po/messages.pot` | 67 | 89 |

The catalogue is larger than upstream's because the port names things upstream
left unnamed (GTK3 stock ids like `gtk-open`/`gtk-cancel`/`gtk-about`, which do
not exist in GTK4 and had to become real translatable strings) and because the
port's shortcuts and menu labels are its own msgids. See
`.reports/translation-parity.md`.

---

## 1. `Bustle.hs` + `uiMain`/`mainB` in `Bustle/UI.hs` — the application

→ `lib/bustle/application.rb` (application) and `lib/bustle/main.rb` (argv
front door). **Present.**

Upstream's `mainB` parses `--debug`, `--pair a b`, and bare log paths, opens one
window per log, and creates one empty window when nothing loaded. Upstream has
no `GtkApplication`; the port uses `Gtk::Application` (the `ruby-gtk` skill
records `Adwaita::Application` as broken in the bindings) so that accelerators
and window actions exist at all.

| Widget | × | CSS | Signals/actions | Notes |
|---|---:|---|---|---|
| `Gtk::Application` | 1 | — | `activate`, `open` | upstream: none; `--debug` → `show_bounds` |

## 2. `diagramWindow` in `data/bustle.ui` + `emptyWindow`/`displayLog`/`setPage` in `Bustle/UI.hs` — the main window

→ `lib/bustle/window.rb` (window). **Present.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Window` `diagramWindow` | 1 | — | `destroy` → `maybeQuit`, `delete-event` → `promptToSave` | port: `Gtk::ApplicationWindow` + `Adwaita::ToolbarView`, `close-request` |
| `Gtk.Stack` `diagramOrNot` | 1 | — | — | three named pages: `InstructionsPage`, `PleaseHoldPage`, `CanvasPage` |
| `Gtk.Paned` `sidebarPaned` (horizontal) | 1 | — | — | stats sidebar \| content |
| `Gtk.Paned` `contentPaned` (vertical) | 1 | — | — | canvas \| details grid |
| `Gtk.Box` `box1` | 1 | — | — | error bar above the stack |
| `Gtk.SizeGroup` (unnamed, horizontal) | 1 | — | — | ties `sidebarHeader` to `sidebarStack` |

Window title/subtitle come from `logWindowTitle`: `*name` for an unsaved
recording, `name` + directory for one log, `a & b` for a pair.

## 3. `header`, `headerPaned`, `sidebarHeader` in `data/bustle.ui` — the header bars

→ `lib/bustle/header_bar.rb` (header bar). **Present.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Paned` `headerPaned` | 1 | — | — | two header bars side by side, titlebar child |
| `Gtk.HeaderBar` `sidebarHeader` | 1 | — | — | hidden until Statistics is ticked |
| `Gtk.StackSwitcher` | 1 | — | — | sidebar title widget, drives `sidebarStack` |
| `Gtk.HeaderBar` `header` | 1 | — | — | |
| `Gtk.MenuButton` `headerRecord` | 1 | `text-button`, `image-button`, `suggested-action` | menu `recordMenu` | label `_Record` + arrow in a `Gtk.Box` |
| `Gtk.Button` `headerStop` | 1 | `destructive-action` | `clicked` → `monitorStop` | label `_Stop`, hidden unless recording |
| `Gtk.MenuButton` `headerOpen` | 1 | `image-button` | menu `openMenu` | |
| `Gtk.MenuButton` (unnamed) | 1 | `image-button` | menu `filterStatsEtc` | the hamburger |
| `Gtk.Button` `headerExport` | 1 | `image-button` | `clicked` → `saveToPDFDialogue` | insensitive until a log is loaded |
| `Gtk.Button` `headerSave` | 1 | `image-button` | `clicked` → `showSaveDialog`, accel `<Control>s` | insensitive until a recording finishes |
| `Gtk.Spinner` `headerSpinner` | 1 | — | — | spins while recording |
| `Gtk.Label` `headerTitle` | 1 | `title` | — | markup |
| `Gtk.Label` `headerSubtitle` | 1 | `subtitle` | — | markup; `Logged <b>%u</b> messages` |

Port keeps all five buttons and both CSS-class sets; title/subtitle stay
`Gtk::Label`s because `Adwaita::WindowTitle` takes no markup (`FINDINGS.md`).
Buttons drive `win.*` actions instead of raw `clicked`.

## 4. `filterStatsEtc`, `openMenu`, `recordMenu` in `data/bustle.ui` + their `onMenuItemActivate` wiring — menus, actions and shortcuts

→ `lib/bustle/menus.rb` (menus / actions / keyboard shortcuts). **Present.**

| Upstream item | Label | Accel | Port action |
|---|---|---|---|
| `GtkMenuItem` `open` | `gtk-open` stock | `<Control>o` (stock) | `win.open` |
| `GtkMenuItem` `openTwo` | `O_pen a Pair of Logs…` | — | `win.open-pair` |
| `GtkMenuItem` `recordSession` | `Record S_ession Bus` | `<Control>e` | `win.record-session` |
| `GtkMenuItem` `recordSystem` | `Record S_ystem Bus` | `<Control>y` | `win.record-system` |
| `GtkMenuItem` `recordAddress` | `Record _Address…` | `<Control>a` | `win.record-address` |
| `GtkMenuItem` `filter` | `_Filter Visible Services…` | `<Control>f` | `win.filter`, insensitive until a log loads |
| `GtkCheckMenuItem` `statistics` | `_Statistics` | `F9` | `win.statistics`, stateful, insensitive until a log loads |
| `GtkSeparatorMenuItem` | — | — | menu section break |
| `GtkImageMenuItem` `about` | `gtk-about` stock | — | `win.about` |

Upstream's three `GtkMenu`s become three `Gio::Menu` models; the check item
becomes a stateful `Gio::SimpleAction`. Insensitivity rules are upstream's:
`widgetSetSensitivity` is called on export/statistics/filter in `displayLog` and
on save in `finishedRecording`.

## 5. `errorBar`/`errorBarTitle`/`errorBarDetails` in `data/bustle.ui` + `displayError`/`hideError` — the error state

→ `lib/bustle/error_bar.rb` (error state). **Present.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.InfoBar` `errorBar` | 1 | — | `response` → hide | hidden by default |
| `Gtk.Label` `errorBarTitle` | 1 | — | — | bold markup |
| `Gtk.Label` `errorBarDetails` | 1 | — | — | small markup, hidden when there is no body |
| `Gtk.ButtonBox` | 1 | — | — | close button |

Four error messages reach it: `Could not read '%s'`, `Couldn't save log: `
(+ the "recover from the temporary file" secondary), `Couldn't export log as
PDF: `, and any `GError` from the monitor except `IoErrorCancelled`. Port uses
`Adwaita::Banner` — see the `use-markup` question in `FINDINGS.md`.

## 6. `InstructionsPage` in `data/bustle.ui` — the empty state

→ `lib/bustle/welcome_page.rb` (empty state). **Present.**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Box` | 1 | — | centred |
| `Gtk.Image` | 1 | `dim-label` | app icon |
| `Gtk.Label` | 1 | `dim-label` | `Welcome to Bustle` |
| `Gtk.Label` | 1 | `dim-label` | `Start recording D-Bus activity with the <b>Record</b> button above` |

Port uses `Adwaita::StatusPage`, which supplies the same icon/title/description
shape; `dim-label` is the status page's own styling.

## 7. `PleaseHoldPage` in `data/bustle.ui` — the waiting page

→ `lib/bustle/please_hold_page.rb` (page). **Present.**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Label` `label5` | 1 | — | `<big><b>Waiting for D-Bus traffic; please hold…</b></big>` |

Port adds a spinner on the page as well as in the header bar.

## 8. `Bustle/UI/Canvas.hs` + `diagramLayout`/`scrolledwindow1` in `data/bustle.ui` — the diagram canvas

→ `lib/bustle/canvas.rb` (canvas page). **Present.**

| Widget | × | CSS | Signals / controllers | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` `scrolledwindow1` | 1 | — | — | |
| `Gtk.Layout` `diagramLayout` | 1 | — | `draw`, `button-press-event` (left button → `regionSelectionUpdate`), two `key-press-event` handlers | GTK4 has no `GtkLayout`; port uses `Gtk::DrawingArea` in a scrolled window |
| `Gtk.Adjustment` | 2 | — | — | step increment = `eventHeight` |

Keyboard navigation (both `key-press-event` handlers, modifier-free only):
`Up`/`Down` previous/next message, `Home`/`End` first/last, `Left`/`Right` one
step horizontally, `space` one page down. Port reproduces all seven on a
`Gtk::EventControllerKey` plus a `Gtk::GestureClick` for selection, and keeps
`canvasClampAroundSelection`, `canvasScrollToBottom` and the centre-offset
scroll.

## 9. `Bustle/UI/DetailsView.hs` + `detailsGrid` in `data/bustle.ui` — the message details pane

→ `lib/bustle/details_view.rb` (pane). **Present.**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Grid` `detailsGrid` | 1 | — | hidden when nothing is selected |
| `Gtk.Label` captions | 5 | `dim-label` | `Type`, `Path`, `Member`, `Arguments`, `Sender` |
| `Gtk.Label` `detailsDestinationCaption` | 1 | `dim-label` | `Destination`, hidden for undirected signals |
| `Gtk.Label` values | 4 | — | `detailsPath`, `detailsMember` (markup), `detailsSender`, `detailsDestination` |
| `Gtk.Stack` `detailsType` | 1 | — | five named pages |
| `Gtk.Label` type pages | 5 | — | `Method call`, `Method return`, `Error`, `Signal`, `Directed signal` |
| `Gtk.ScrolledWindow` + `Gtk.TextView` `detailsArguments` | 1 | — | formatted variants, one per line |

## 10. `Bustle/StatisticsPane.hs` + `sidebarStack`/`frequencySW`/`durationSW`/`sizeSW` — the statistics sidebar

→ `lib/bustle/statistics_pane.rb` (sidebar pane). **Present.**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Stack` `sidebarStack` | 1 | — | three pages, switched from the sidebar header |
| `Gtk.ScrolledWindow` | 3 | — | `frequencySW`, `durationSW`, `sizeSW` |
| `Gtk.TreeView` | 3 | — | built in Haskell, headers visible |
| `Gtk.ListStore` | 3 | — | `FrequencyInfo`, `TimeInfo`, `SizeInfo` |
| `Gtk.CellRendererText` | repeater | — | 7pt; member renderer ellipsizes at start, right-aligned, 30 chars |
| `Gtk.CellRendererProgress` | 1 | — | frequency bar, `2 + count * 98 / max` |

Columns — frequency: `Member` (type word `Method`/`Signal` + member),
`Frequency` (min width 120); duration: `Method`, `Total`, `Calls`, `Mean`
(`%.1f ms`); size: `Member` (`Method call`/`Method return`/`Error`/`Signal`;
returns italic, errors red), `Smallest`, `Mean`, `Largest` via `formatSize`.
Port renders them with `Gtk::ColumnView` factories.

## 11. `Bustle/UI/FilterDialog.hs` — the service filter dialog

→ `lib/bustle/filter_dialog.rb` (dialog). **Present.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Dialog` | 1 | — | `response` (`Close`) | sized 7/8 × 1/2 of the parent, transient |
| `Gtk.Label` instructions | 1 | — | — | wrapped, 600px: `Unticking a service hides its column…` |
| `Gtk.ScrolledWindow` | 1 | — | — | automatic/automatic |
| `Gtk.TreeView` | 1 | — | — | 600×371, no headers, rules hint |
| `Gtk.CellRendererToggle` | 1 | — | `toggled` → flip the row | |
| `Gtk.CellRendererText` | 1 | — | — | `formatNames`: unique name, or namespace-grouped `ns.{a,b}` |

Returns the set of names to hide; UI.hs then re-renders with
`processWithFilters`.

## 12. `Bustle/UI/OpenTwoDialog.hs` + `data/OpenTwoDialog.ui` — open a pair of logs

→ `lib/bustle/open_two_dialog.rb` (dialog). **Present.**

| Widget | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.Dialog` `openTwoDialog` | 1 | `delete-event` → hide, `response` | title `Open a Pair of Logs`, transient, reused not destroyed |
| `Gtk.FileChooserButton` | 2 | `file-set` → `updateOpenSensitivity`, `current-folder-changed` → propagate folder | `Select session bus log`, `Select system bus log` |
| `Gtk.Label` | 2 | — | `Session bus log:`, `System bus log:` |
| `Gtk.Button` `openTwoOpenButton` | 1 | — | insensitive until both files are chosen |
| `Gtk.Button` `openTwoCancelButton` | 1 | — | `gtk-cancel` |

The folder-propagation rule (copy chooser 1's folder to chooser 2 only while
chooser 2 has no file selected, in both directions) is behaviour, not layout,
and is reproduced.

## 13. `Bustle/UI/RecordAddressDialog.hs` + `data/RecordAddressDialog.ui` — record an arbitrary address

→ `lib/bustle/record_address_dialog.rb` (dialog). **Present.**

| Widget | × | Signals | Notes |
|---|---:|---|---|
| `Gtk.Dialog` `recordAddressDialog` | 1 | `response` → callback, then destroy | title `Record Address`, transient |
| `Gtk.Label` | 1 | — | `Address:` |
| `Gtk.Entry` `recordAddressEntry` | 1 | `changed` → enable/disable Record | placeholder with the `e.g. unix:abstract=…` translator comment |
| `Gtk.Button` `recordAddressRecord` | 1 | — | `_Record`, insensitive while the entry is empty |
| `Gtk.Button` `recordAddressCancel` | 1 | — | `gtk-cancel` |

Port splits the label and the placeholder across an `Adwaita::EntryRow` title
and its group description, because `AdwEntryRow` has no placeholder
(`FINDINGS.md`).

## 14. `showOpenDialog` in `Bustle/UI.hs` — open one log

→ `lib/bustle/open_dialog.rb` (file chooser). **Present.**

`Gtk.FileChooserDialog`, action `Open`, modal, local-only, `gtk-cancel`/
`gtk-open`. Port uses `Gtk::FileDialog` and adds file filters (its own
addition, noted in the file).

## 15. `saveToPDFDialogue` in `Bustle/UI.hs` — export the diagram as PDF

→ `lib/bustle/pdf_export.rb` (file chooser + Cairo export). **Present.**

`Gtk.FileChooserDialog`, action `Save`, modal, local-only, overwrite
confirmation, current name `<log title>.pdf`, current folder = the log's
directory unless it is an unsaved recording. Renders with `withPDFSurface` +
`drawDiagram False`.

## 16. `Bustle/UI/Recorder.hs` `recorderChooseFile` + `showSaveDialog`/`startRecording`/`recorderRun`/`processBatch`/`finishedRecording` in `Bustle/UI.hs` — the recording flow

→ `lib/bustle/recorder.rb` (file chooser + recording flow). **Present.**

`Gtk.FileChooserDialog`, action `Save`, `gtk-cancel`/`gtk-new`, overwrite
confirmation, pre-filled with the temporary file's basename; then `fileMove`
with `FileCopyOverwrite`. The flow around it: hide Record/Open, show and focus
Stop, start the spinner, set the `Recording %s…` title, show `PleaseHoldPage`,
batch incoming messages on a 200 ms timeout, update `Logged <b>%u</b>
messages`, switch to `CanvasPage` on first output, and on stop either reload
the recorded log and enable Save or fall back to `InstructionsPage`.

## 17. `promptToSave` in `Bustle/UI.hs` — unsaved-recording confirmation

→ `lib/bustle/window.rb` (alert dialog, built inside the window rather than its
own file). **Present.**

`Gtk.MessageDialog`, modal, warning, `Save log '%s' before closing?` with
secondary `If you don't save, this log will be lost forever.` and three
responses: `Close _Without Saving`, `gtk-cancel`, `gtk-save`. Port uses
`Adwaita::AlertDialog` with the same three responses.

## 18. `Bustle/UI/AboutDialog.hs` — the about dialog

→ `lib/bustle/about_dialog.rb` (dialog). **Present.**

`Gtk.AboutDialog`, modal and transient, with name `Bustle`, version, comments
`Someone's favourite D-Bus profiler`, the freedesktop wiki website, the
`LICENSE` file read off disk (warning on failure, no license shown), copyright
`© 2008–2017 Will Thompson, Collabora Ltd. and contributors`, the logo icon
name, and the ten-name author list — all ten are carried over.

## 19. `Bustle/Noninteractive.hs` — the batch CLI modes

→ `lib/bustle/noninteractive.rb` (CLI). **Present.** `--count`, `--time`,
`--dot`; each loads a log and prints, no widgets.

## 20. `c-sources/bustle-pcap.c` (+ `pcap-monitor.c`/`.h`) — the `bustle-pcap` recorder binary

→ `lib/bustle/pcap_cli.rb` (CLI). **Present.** `--session`/`--system`/
`--address`, `-v/--verbose`, SIGINT stop.

## 21. `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` — the live bus monitor

→ `lib/bustle/monitor.rb` (service object behind the recording UI).
**Present.** Signals `message-logged` and `stopped` (domain, code, message),
`monitorStop`. The one deliberate difference is recorded in the file: upstream's
C monitor can hide the monitor's own traffic and the port does not.

## 22. Data files and catalogue

| Upstream | Port | Kind | Present |
|---|---|---|---|
| `data/org.freedesktop.Bustle.desktop.in` | `data/org.rubygtkproject.Bustle.desktop{,.in}` | desktop entry | yes |
| `data/org.freedesktop.Bustle.appdata.xml.in` | `data/org.rubygtkproject.Bustle.appdata.xml{,.in}` | appstream metadata | yes |
| `data/icons/hicolor/**` (5 PNG + 2 SVG) | same shape, renamed app id | icons | yes |
| `po/LINGUAS`, `po/messages.pot`, `po/en.po` | same three | gettext catalogue | yes |
| `src-hgettext/Bustle/Translation.hs`, `GetText.hs` | `lib/bustle/translation.rb` | i18n plumbing | yes |
| `data/bustle.ui`, `data/OpenTwoDialog.ui`, `data/RecordAddressDialog.ui` | — | GtkBuilder XML | n/a by design — the house style builds widgets as memoized methods |

## Non-widget modules (for completeness)

All present and one-to-one: `Bustle/Diagram.hs` → `lib/bustle/diagram.rb`,
`Renderer.hs` → `renderer.rb`, `Regions.hs` → `regions.rb`, `Stats.hs` →
`stats.rb`, `Types.hs` → `types.rb`, `Marquee.hs` → `marquee.rb`, `Loader.hs` →
`loader.rb`, `Loader/Pcap.hs` → `pcap_loader.rb`, `VariantFormatter.hs` →
`variant_formatter.rb`, `Util.hs` → `util.rb`, `Missing.hs` → `missing.rb`.
`Bustle/Application/Monad.hs` has no port file: it is the `ReaderT`/`StateT`
stack Haskell needs to thread `BConfig`/`BState`, and its content lives in
`Application`'s and `Window`'s own state.

## Blockers

> Corrected at port `6e6fccb` by `.reports/accountability-ensurance.md` finding
> A5. Items 1 and 2 as first written were false by then and are replaced; item 3
> is narrowed to the part that is still true.

1. **Every component has now been run.** `test/drive_bustle.rb` walks all 22
   components with 262 checks and 21 screenshots (`DRIVE OK`), and
   `test/drive_recording.rb` records a real session bus through the GUI with 6
   more. "Present" below therefore means "appears on screen and responds", except
   for the parts of component 21 named in A1 and A2 of that report: the pkexec
   exit-status mapping and `Monitor#stop` against a subprocess the port may not
   signal are executed by nothing.
2. **One bindings question is settled and one is closed.** `GLib.format_size`
   backs the statistics pane's three size columns and works (driven,
   `drive_bustle.rb:458-463`). `Adwaita::Banner` is no longer used anywhere —
   the error bar is a `Gtk::Box` in the error colours — so its `use_markup`
   version floor is moot; libadwaita in this dev shell is 1.9.3.
3. **The symbol table is still not built.** `gir-symbols.sh` was not run, so
   every namespaced match in both scans stayed classified `widget` and the
   strikes were made by reading. The scans themselves have now been run on both
   trees (`.reports/component-identification.md`); it is only the classifier
   that is missing.
4. **Two upstream components have no `lib/*.rb` of their own**, by choice rather
   than omission: `promptToSave`'s alert dialog lives inside
   `lib/bustle/window.rb`, and `recorderChooseFile`'s save chooser inside
   `lib/bustle/recorder.rb`. Both match where upstream puts them (`UI.hs` and
   `UI/Recorder.hs` respectively are not widget classes), but it means the
   one-upstream-file-to-one-`lib`-file rule is not literally 1:1 here.
