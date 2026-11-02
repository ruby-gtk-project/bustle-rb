# Component parity — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `04031bc` |
| Units with parity | **5 / 22** |
| Units absent entirely | 5 |

Units with parity: welcome page, error bar, about dialog, open dialog,
batch modes. Everything else below has at least one gap.

---

## Unit: CLI — `Bustle.hs` -> `lib/bustle/main.rb`

| Facet | Upstream | Port | Verdict |
|---|---|---|---|
| `[LOGFILE…]` | one window per log | same | parity |
| `--pair S Y` | one window, two logs | same | parity |
| `--count/--time/--dot` | exactly one log | same | parity |
| `--help` | usage to stderr, exit 0 | same | parity |
| `--debug` | draw shape bounds | same | parity |

Usage text is not translated upstream either. **parity**, with one caveat
recorded under the window unit: upstream's usage block does not advertise
recording because recording is reached from the UI, so the CLI's silence is
not evidence the port is complete.

---

## Unit: application — `Bustle/UI.hs`(`uiMain`/`mainB`) + `Application/Monad.hs` -> `lib/bustle/application.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| one window per log | ✓ | ✓ | parity |
| quit on last window | `maybeQuit` on window count | `Gtk::Application` does it | parity |
| initial window re-used by Open | ✓ (`bInitialWindow`) | ✗ — `action_open` always loads into *its own* window | **gap**: upstream's first window is the one a command-line failure and a subsequent Open both land in; the port never tracks it |
| Adwaita init | n/a | `Adwaita.init` + `Gtk::Application` | parity |

---

## Unit: main window — `Bustle/UI.hs` + `bustle.ui`▸`diagramWindow` -> `lib/bustle/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| window | 1 | 1 | — | ✗ `delete-event` | ✓ | **gap**: no `close-request` handler, so `promptToSave` never runs and a recorded log is lost silently |
| `Gtk.Paned` | 3 | 2 | — | — | — | the titlebar `headerPaned` is correctly subsumed by `Adwaita::ToolbarView`; **correspondence** |
| header bars | 2 | 2 | — | — | ✓ | parity (see header unit) |
| `Gtk.Stack` `diagramOrNot` | 1 | 1 | — | — | — | 3 pages both sides, but `PleaseHoldPage` is unreachable — see below |
| `Gtk.MenuButton` `headerRecord` | 1 | **0** | ✗ `text-button image-button suggested-action` | ✗ | ✗ `_Record`, ✗ `Record a new log` | **gap**: no Record button |
| `Gtk.Button` `headerStop` | 1 | **0** | ✗ `destructive-action` | ✗ `clicked` | ✗ `_Stop` | **gap**: no Stop button |
| `Gtk.Button` `headerSave` | 1 | **0** | ✗ `image-button` | ✗ `clicked` | ✗ `Save` | **gap**: no Save button, no save flow |
| `Gtk.Spinner` `headerSpinner` | 1 | 1 | — | ✗ start/stop | — | **gap**: moved into `please_hold_page`, which is never shown, and nothing ever starts or stops it in response to recording |
| `Gtk.Button` `headerExport` | 1 | 1 | — | ✓ | ✓ | parity, except it is never disabled→enabled by `action.enabled` on first load… it is: `NEEDS_LOG` covers it. parity |

Window title logic (`logWindowTitle`/`logTitle`): ported faithfully, including
the `*name` asterisk for a recorded log — **but the `:recorded` branch of
`Window::LogDetails` is unreachable**, because nothing constructs it. Dead
code standing in for a feature.

`show_waiting` (the `PleaseHoldPage` switch) and `Canvas#scroll_to_bottom`
have **no callers anywhere in `lib/` or `exe/`**. Both exist only for the
recorder that was not written.

Driven: cannot drive. `lib/bustle/window.rb` builds
`Adwaita::ApplicationWindow.new(@app)`, which `.claude/skills/ruby-gtk`
records as **broken in the Ruby bindings** ("Use `Gtk::Application` +
`Gtk::ApplicationWindow`"). The file's own comment asserts the opposite
without evidence. **gap**: unverified against a running app, and the skill
says it will not run.

---

## Unit: menus / actions / accelerators — `bustle.ui`▸3 menus -> `lib/bustle/menus.rb`

| Item | Upstream label | Upstream accel | Port | Verdict |
|---|---|---|---|---|
| open | `gtk-open` (stock → `_Open`) | `Ctrl+O` | `win.open`, `_Open…` | **gap** (text): upstream's msgid is the stock id, the port invents `_Open…` |
| open pair | `O_pen a Pair of Logs…` | — | ✓ | parity |
| filter | `_Filter Visible Services…` | `Ctrl+F` | ✓ | parity |
| statistics | `_Statistics` (check item) | `F9` | ✓ stateful action | parity |
| about | `gtk-about` (stock → `_About`) | — | `_About Bustle` | **gap** (text): invented msgid |
| **record session bus** | `Record S_ession Bus` | `Ctrl+E` | **absent** | **gap** |
| **record system bus** | `Record S_ystem Bus` | `Ctrl+Y` | **absent** | **gap** |
| **record address** | `Record _Address…` | `Ctrl+A` | **absent** | **gap** |
| **save log** | `Save` (tooltip on `headerSave`) | `Ctrl+S` | **absent** | **gap** |
| export as PDF | tooltip only, **no accelerator** | bound to `Ctrl+S` | **gap**: the port rebinds upstream's Save accelerator to a different command. A user who learned `Ctrl+S` in Bustle now exports a PDF instead of saving the log |

Insensitivity: upstream disables `filter` and `statistics` until a log loads;
the port disables `filter`, `statistics` and `export-pdf`. Upstream's
`headerExport` also starts insensitive, so that is parity.

Messages: 5 of the menu's msgids match upstream byte for byte, 2 are invented
(`_Open…`, `_About Bustle`), 3 are missing (`Record S_ession Bus`,
`Record S_ystem Bus`, `Record _Address…`). **gap** — open in
`translation-parity.md`.

---

## Unit: header bars — `bustle.ui`▸`header`/`sidebarHeader` -> `lib/bustle/header_bar.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adwaita.HeaderBar` | 2 | 2 | — | — | — | parity |
| title/subtitle labels | 2 | 1 `WindowTitle` | `title`,`subtitle` → platform | — | ✓ | correspondence |
| `Gtk.StackSwitcher` | 1 | 1 | — | — | — | parity |
| open `MenuButton` | 1 | 1 | `image-button` → icon button | — | ✓ `Open an existing log` | parity |
| hamburger `MenuButton` | 1 | 1 | `image-button` | — | ✗ `Main Menu` tooltip invented (upstream has none) | **gap** (text): extra msgid |
| export `Button` | 1 | 1 | `image-button` | ✓ | ✓ `Export as PDF` | parity |
| record `MenuButton`, stop/save `Button`, spinner | 4 | 0 | ✗ | ✗ | ✗ | **gap**: the whole right-hand half of upstream's header bar is absent |

`GtkSizeGroup` tying `sidebarHeader` to `sidebarStack`: not reproduced. Minor,
but it is why upstream's sidebar header lines up with the sidebar; the port
instead sets `width_request = 400` on the sidebar `ToolbarView`. **gap**
(cosmetic, recorded rather than excused).

---

## Unit: welcome page — `bustle.ui`▸`InstructionsPage` -> `lib/bustle/welcome_page.rb`

| Widget | Up × | Port × | CSS | Text | Verdict |
|---|---:|---:|---|:-:|---|
| container | `Gtk.Box` 1 | `Adwaita.StatusPage` 1 | — | — | correspondence |
| icon | `Gtk.Image` 1 | `icon-name` | `dim-label` | — | correspondence |
| title label | 1 | `StatusPage#title` | `dim-label` | ✓ `Welcome to Bustle` | parity |
| body label | 1 | 1 | ✓ `dim-label` | ✗ | **gap**: msgid differs by one byte |

The body msgid upstream is
`Start recording D-Bus activity with the <b>Record</b> button above\n You can
also run <i>dbus-monitor --pcap</i> from the command line` — note the **space
after `\n`**, which `data/bustle.ui` contains. The port writes `…above\nYou
can…`. Different lookup key, no translation. **gap.**

Behaviour note, not a widget row: this page tells the user to press a Record
button that the port does not have. The empty state instructs the user to do
something impossible.

---

## Unit: please-hold page — `bustle.ui`▸`PleaseHoldPage` -> `lib/bustle/please_hold_page.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| label | 1 | `StatusPage#title` | ✗ | **gap**: upstream's msgid is `<big><b>Waiting for D-Bus traffic; please hold…</b></big>` (markup included, because the label is `use-markup`); the port registers the bare sentence |
| `Gtk.Spinner` | 0 (it lives in the header) | 1 | — | extra, explained in the file's comment |

Driven: ✗ — the page is added to the stack and **never selected**, because
`Window#show_waiting` has no caller. **gap**: the widget exists, the state
does not.

---

## Unit: error bar — `bustle.ui`▸`errorBar` -> `lib/bustle/error_bar.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.InfoBar` | 1 | `Adwaita.Banner` | — | ✓ `response`→`button-clicked` | ✓ `_Close` | correspondence |
| title label | 1 | banner title (markup) | — | — | — | parity |
| details label | 1 | 1 | ✓ `dim-label` | — | — | parity |

The failure paths that *reach* it are where the gaps are: upstream routes
unreadable log, failed save, failed PDF export **and monitor error** here. The
port routes unreadable log and failed PDF export. Save and monitor do not
exist. Those are recorded against their own units, not here. **parity** for
the widget.

`Adwaita::Banner#use_markup` is a libadwaita 1.7 property; unverified against
the gem in this checkout, and the banner's whole title is passed as Pango
markup. Flagged, not counted.

---

## Unit: canvas — `Bustle/UI/Canvas.hs` + `bustle.ui`▸`diagramLayout` -> `lib/bustle/canvas.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| `Gtk.Layout` in `ScrolledWindow` | ✓ | `Gtk::DrawingArea` + explicit `set_size_request` | correspondence |
| `draw` | `canvasDraw`, clipped to visible rect | ✓ | parity |
| left-click selects region at y, grabs focus | ✓ | ✓ `GestureClick` button 1 | parity |
| Left/Right = h-step | ✓ | ✓ | parity |
| space = v-page | ✓ | ✓ | parity |
| Up/Down/Home/End = move selection | ✓ | ✓ | parity |
| selection highlight as an extra `Highlight` shape | ✓ | ✓ | parity |
| `canvasClampAroundSelection` on idle | ✓ | ✓ (synchronous) | parity |
| `canvasScrollToBottom` during recording | ✓ | method exists, **no caller** | **gap**: dead code, blocked on the recorder |
| partial invalidation of the two changed stripes | ✓ | whole visible area | explained in the file; acceptable |

Driven: ✗ — no test, no app run (GTK4 gem is not installed in this checkout,
see `test-parity.md`).

---

## Unit: details view — `Bustle/UI/DetailsView.hs` + `bustle.ui`▸`detailsGrid` -> `lib/bustle/details_view.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Gtk.Grid` | 1 | `Adwaita.PreferencesGroup` | — | correspondence |
| caption labels | 6 | row titles | ✓ Type/Path/Member/Arguments/Sender/Destination | parity |
| value labels (selectable) | 4 | row subtitles, `subtitle-selectable` | — | parity |
| `Gtk.Stack` `detailsType`, 5 pages | 1 | one row subtitle | ✓ all 5 msgids match | correspondence |
| `Gtk.TextView` `detailsArguments` | 1 | 1 | — | parity |
| destination hidden for an undirected signal | ✓ | ✓ | — | parity |

`dim-label` on the captions becomes `Adwaita::ActionRow` title styling —
correspondence. **parity.**

---

## Unit: statistics pane — `Bustle/StatisticsPane.hs` + `bustle.ui`▸`sidebarStack` -> `lib/bustle/statistics_pane.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| `Gtk.Stack` of 3 `ScrolledWindow` | ✓ | ✓ | parity |
| Frequencies: Member + Frequency | `TreeView` + `CellRendererProgress`, min width 120 | `ColumnView` + `ProgressBar`, fixed 120 | correspondence |
| Durations: Method/Total/Calls/Mean | ✓ | ✓ | parity |
| Sizes: Member/Smallest/Mean/Largest | ✓ | ✓ | parity |
| member cell: kind + start-ellipsised member, 30 chars, right-aligned | ✓ | ✓ | parity |
| returns italic, errors red | ✓ | ✓ | parity |
| 7pt text on all three views | ✓ | ✗ | **gap**: upstream shrinks the tables to 7pt so a 30-char member fits the sidebar; the port leaves them at the default size |
| sortable columns | `TreeView` headers visible, not sortable | `ColumnView`, not sortable | parity |
| hidden at startup, revealed by F9 | ✓ | ✓ | parity |
| `Missing.formatSize` for the size columns | `g_format_size()` | **reimplemented in Ruby with its own msgids** | **gap** — see below |

`Bustle/Missing.hs` calls `g_format_size()`, whose strings live in **GLib's**
catalogue and are already translated in every language GLib ships. The port's
`lib/bustle/missing.rb` reimplements the formatting and marks `%u byte` /
`%u bytes` in **Bustle's** domain, where nobody has translated them, and
hard-codes English SI unit suffixes. Two invented msgids and a localisation
regression. **gap.**

---

## Unit: filter dialog — `Bustle/UI/FilterDialog.hs` -> `lib/bustle/filter_dialog.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| 7/8 window width, half its height, transient, modal | ✓ | ✓ | parity |
| instructions label, 600px wrap | ✓ | wrap, no width | parity |
| headerless `TreeView` 600×371, toggle + name column | ✓ | `ListBox` of `ActionRow` + `CheckButton`, `boxed-list` | correspondence |
| `org.example.{Foo,Bar}` namespace grouping | ✓ | ✓ | parity |
| unticked names returned as the hidden set, log re-rendered via `processWithFilters` | ✓ | ✓ | parity |
| Close button applies | ✓ | ✓ (and on `close-request`) | parity |
| instructions msgid | ✓ | ✓ byte-identical | parity |
| dialog title | `Filter Visible Services` — **not marked upstream**, the window title is set from the untranslated string | marked `_("Filter Visible Services")` | **gap**: extra msgid. Also upstream's `Close` is the stock `gtk-close`; the port invents `_Close` |

Styling: `suggested-action` on Close is the port's addition; upstream's Close
is an ordinary dialog button. **gap** (cosmetic): a Close button that only
dismisses should not be the suggested action.

---

## Unit: open-pair dialog — `OpenTwoDialog.hs` + `OpenTwoDialog.ui` -> `lib/bustle/open_two_dialog.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Gtk.Dialog` | 1 | `Adwaita.Window` | ✓ `Open a Pair of Logs` | correspondence |
| `Gtk.Table` + 2 labels | 1+2 | `PreferencesGroup` + 2 `ActionRow` | ✓ `Session bus log:` / `System bus log:` | correspondence |
| `Gtk.FileChooserButton` ×2 | 2 | `Gtk::Button` + `Gtk::FileDialog` ×2 | ✓ `Select session bus log` / `Select system bus log` | correspondence |
| Cancel / Open | 2 | 2 | ✗ | **gap** (text): upstream's are stock `gtk-cancel`/`gtk-open`; the port invents `_Cancel`/`_Open` |
| Open sensitive only when both set | ✓ | ✓ | — | parity |
| each chooser seeds the other's folder while the other is empty | ✓ | ✓ | — | parity |
| hidden (not destroyed) and **unselected** on response | ✓ | `window.close`, choices kept | **gap**: upstream resets both choosers so the next Open-a-pair starts clean; the port's dialog object is not reused, so re-opening builds a fresh one — behaviour coincidentally matches, but the `(none chosen)` / `Choose…` placeholder strings are two more invented msgids |
| group description | the `.ui` tooltip `Display two logs—…side by side.` | used as the group description | ✓ byte-identical | parity |

---

## Unit: about dialog — `Bustle/UI/AboutDialog.hs` -> `lib/bustle/about_dialog.rb`

Name, version, comments, website, 10 authors, copyright string, licence read
off disk with a warning on failure, logo icon. All present and byte-identical.
`Gtk::AboutDialog` rather than `Adwaita::AboutDialog`, matching upstream's
widget. **parity.**

---

## Unit: open dialog — `Bustle/UI.hs`▸`showOpenDialog` -> `lib/bustle/open_dialog.rb`

Open mode, modal, loads into a window. Filters (`D-Bus logs`, `All files`,
`Open a Log` title) are the port's addition — three invented msgids, recorded
in `translation-parity.md`. The chooser itself is **parity**; upstream's dialog
is built with no title and no filter, so the port is strictly better here and
the only cost is catalogue drift.

---

## Unit: PDF save dialog — `Bustle/UI.hs`▸`saveToPDFDialogue` -> `lib/bustle/pdf_export.rb`

| Facet | Up | Port | Verdict |
|---|---|---|---|
| Save mode, modal, local-only, overwrite confirmation | ✓ | `Gtk::FileDialog` (confirmation is the portal's) | correspondence |
| current name `<logTitle>.pdf` | ✓ | ✓ | parity |
| folder defaults to the log's directory | ✓ | ✓ | parity |
| renders to a Cairo PDF surface the size of the diagram | ✓ | ✓ | parity |
| error msgid | `Couldn't export log as PDF: ` (trailing space, message concatenated) | `Couldn't export log as PDF: %s` | **gap**: reworded msgid |
| title msgid | n/a (no title upstream) | `Export as PDF` reused | acceptable |

---

## Unit: batch modes — `Bustle/Noninteractive.hs` -> `lib/bustle/noninteractive.rb`

`--count` ` %4d %6s %s.%s`, `--time` ` %9.4f %3d %9.4f %s.%s`, `--dot`
`digraph bustle { … }` with `nub`-ed method-call edges, warnings to stderr,
`Couldn't parse '%s': %s` and a failure exit on load error. Formats and
msgids match. **parity**, with one note: upstream passes the member through
`formatMemberName`; the port interpolates `info.member` directly. For a plain
member name these agree.

---

## Units with no port file at all

| Unit | What the user loses |
|---|---|
| `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` | live recording of any bus |
| `Bustle/UI/Recorder.hs` | the record→watch→stop→save-as flow, the message counter in the subtitle, the temp file under the cache dir, the manual-recovery warning |
| `Bustle/UI/RecordAddressDialog.hs` + `RecordAddressDialog.ui` | recording an arbitrary bus by address |
| `Bustle/UI.hs`▸`showSaveDialog`/`promptToSave` | saving a recorded log, and the "Save log '%s' before closing?" guard that stops it being thrown away |
| `c-sources/bustle-pcap.c` | the standalone `bustle-pcap` CLI recorder the appdata and the welcome page both reference |

Together these are **the half of Bustle that produces logs**. The port can
only read `.bustle` files somebody else recorded. The appdata the port ships
still claims "It's now possible to monitor the system bus … It's also possible
to monitor an arbitrary bus by address" — it is not, in this port.

`.reports/component-inventory.md` lists "Live recording" and "pcap parsing" as
blockers with a decision to be made. pcap parsing was solved
(`lib/bustle/pcap_loader.rb`, 495 lines). Recording was not attempted, and no
file in `lib/` says so. The absence is invisible from inside the code — which
is what `accountability-ensurance.md` is about.

## Stylesheet

Neither side ships a `.css` file. Every class used on both sides is a GTK or
libadwaita platform class. No app-namespaced class exists to compare, and no
`set_css_name` on either side. **Clean.**

## Driven

Nothing was driven. `require "bustle"` fails in this checkout — the `gtk4`
gem is not installed, and `lib/bustle/diagram.rb` requires it at load time
from `lib/bustle.rb`, so even the backend-only half cannot be loaded despite
`lib/bustle.rb`'s comment that it "can be used on their own". No screenshot,
no `gtk_driver.rb` session, no behaviour on any unit confirmed by execution.
Every `parity` verdict above is a reading, not an observation.
