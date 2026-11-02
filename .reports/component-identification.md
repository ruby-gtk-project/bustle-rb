# Component identification — bustle-rb

| | |
|---|---|
| Upstream | `master` @ `0a8cf38` (Haskell + GTK3 + GtkBuilder) |
| Port | `ruby` @ `16f6787` (Ruby + GTK4 + Libadwaita) |
| Scanned with | `.claude/skills/component-identification/scripts/component-scan.sh` |
| Upstream rows | 45 across 3 `.ui` files (the Haskell builds almost nothing directly) |
| Port rows | 109 across `lib/bustle/*.rb` |

Upstream has declarative UI, so Step 1 applies: `data/bustle.ui` (925 lines),
`data/OpenTwoDialog.ui` (133), `data/RecordAddressDialog.ui` (111) **are** the
inventory, and the Haskell pulls widgets out of them by id with
`builderGetObject`. There are no `<template>` roots — every root is a top-level
named object (`diagramWindow`, `openTwoDialog`, `recordAddressDialog`, plus the
three `GtkMenu`s), which is the unit list.

The port has no `.ui` files, by design: widgets are memoized methods per the
`ruby-gtk` skill.

**Upstream is GTK3.** `Gtk.Menu`, `Gtk.ImageMenuItem`, `Gtk.CheckMenuItem`,
`Gtk.SeparatorMenuItem`, `Gtk.Table`, `Gtk.Layout`, `Gtk.InfoBar`,
`Gtk.ButtonBox` and `Gtk.FileChooserButton` have no GTK4 counterpart, so the
widget stream cannot be diffed on type. Every one of them is recorded below as
a substitution with the port's replacement named, and the comparison is carried
on the CSS, signal, action and text axes in `component-parity.md`.

## File mapping

```
Bustle/UI.hs + data/bustle.ui▸diagramWindow      -> lib/bustle/window.rb
                                                  + lib/bustle/header_bar.rb
                                                  + lib/bustle/error_bar.rb
                                                  + lib/bustle/welcome_page.rb
                                                  + lib/bustle/please_hold_page.rb
                                                  + lib/bustle/pdf_export.rb
                                                  + lib/bustle/open_dialog.rb
data/bustle.ui▸openMenu/recordMenu/filterStatsEtc -> lib/bustle/menus.rb
Bustle/UI/Canvas.hs + bustle.ui▸diagramLayout     -> lib/bustle/canvas.rb
Bustle/UI/DetailsView.hs + bustle.ui▸detailsGrid  -> lib/bustle/details_view.rb
Bustle/StatisticsPane.hs + bustle.ui▸sidebarStack -> lib/bustle/statistics_pane.rb
Bustle/UI/FilterDialog.hs                         -> lib/bustle/filter_dialog.rb
Bustle/UI/OpenTwoDialog.hs + OpenTwoDialog.ui     -> lib/bustle/open_two_dialog.rb
Bustle/UI/RecordAddressDialog.hs
                   + RecordAddressDialog.ui       -> lib/bustle/record_address_dialog.rb
Bustle/UI/AboutDialog.hs                          -> lib/bustle/about_dialog.rb
Bustle/UI/Recorder.hs + UI.hs▸recording half      -> lib/bustle/recorder.rb
Bustle/Monitor.hs + c-sources/pcap-monitor.c      -> lib/bustle/monitor.rb
c-sources/bustle-pcap.c                           -> lib/bustle/pcap_cli.rb + exe/bustle-pcap
Bustle.hs                                         -> lib/bustle/main.rb + exe/bustle
Bustle/Application/Monad.hs + UI.hs▸uiMain/mainB  -> lib/bustle/application.rb
Bustle/Noninteractive.hs                          -> lib/bustle/noninteractive.rb
Bustle/{Renderer,Diagram,Regions,Stats,Types,
  Marquee,Missing,Util,VariantFormatter,Loader,
  Loader/Pcap,Translation}.hs                     -> the same-named lib/bustle/*.rb
```

Every upstream source file has a port file opposite it. There is no unit-level
hole; the gaps found are inside units.

## Unit: main window — `bustle.ui`▸`diagramWindow` + `Bustle/UI.hs`

| Widget | × | CSS / name | Signals & actions | Port counterpart |
|---|---:|---|---|---|
| `Gtk.Window` `diagramWindow` | 1 | — | `delete-event`→`promptToSave`, `destroy`→`maybeQuit` | `Gtk::ApplicationWindow`, `window.rb:205` (`Adwaita::ApplicationWindow` is broken in the bindings) |
| `Gtk.Paned` `headerPaned` | 1 | — | — | folded into `Adwaita::ToolbarView` + `sidebar_paned`, `window.rb:213,236` |
| `Gtk.HeaderBar` `header` | 1 | — | — | `Adwaita::HeaderBar`, `header_bar.rb:97` |
| `Gtk.HeaderBar` `sidebarHeader` | 1 | — | shown/hidden by Statistics | `header_bar.rb:99` |
| `Gtk.StackSwitcher` | 1 | — | — | `header_bar.rb:106` |
| `Gtk.MenuButton` `headerRecord` | 1 | `text-button`, `image-button`, `suggested-action` | `recordMenu` | `header_bar.rb:142`, `suggested-action` + `Adwaita::ButtonContent` |
| `Gtk.Button` `headerStop` | 1 | `destructive-action` | `buttonActivated`→`monitorStop` | `header_bar.rb:159` |
| `Gtk.MenuButton` `headerOpen` | 1 | `image-button` | `openMenu` | `header_bar.rb:168` |
| `Gtk.MenuButton` (main menu) | 1 | `image-button` | `filterStatsEtc` | `header_bar.rb:192` |
| `Gtk.Button` `headerSave` | 1 | `image-button` | `Ctrl+S`, `showSaveDialog` | `header_bar.rb:176`, `win.save` |
| `Gtk.Button` `headerExport` | 1 | `image-button` | `saveToPDFDialogue` | `header_bar.rb:184`, `win.export-pdf` |
| `Gtk.Spinner` `headerSpinner` | 1 | — | `spinnerStart`/`Stop` | `header_bar.rb:136` |
| `Gtk.Label` `headerTitle` | 1 | `title` | `labelSetMarkup` | `header_bar.rb:116` |
| `Gtk.Label` `headerSubtitle` | 1 | `subtitle` | `labelSetMarkup` | `header_bar.rb:125` |
| `Gtk.InfoBar` `errorBar` | 1 | `message_type=error`, `show_close_button` | `infoBarResponse`→hide | `Adwaita::Banner`, `error_bar.rb:50` — **style not carried** |
| `Gtk.Label` `errorBarTitle` | 1 | `selectable`, `use_markup`, `wrap` | — | banner title, `error_bar.rb:50` — **not selectable** |
| `Gtk.Label` `errorBarDetails` | 1 | `selectable`, `use_markup`, `wrap` | shown only when there are details | `error_bar.rb:57` — **not selectable** |
| `Gtk.Stack` `diagramOrNot` | 1 | pages `InstructionsPage`/`PleaseHoldPage`/`CanvasPage` | `stackSetVisibleChildName` | `window.rb:217` |
| `Gtk.Paned` `sidebarPaned` | 1 | — | — | `window.rb:236` |
| `Gtk.Paned` `contentPaned` | 1 | — | — | `diagram_paned`, `window.rb:243` |
| `Gtk.SizeGroup` (unnamed, `:919`) | 1 | horizontal, over `sidebarHeader` + `sidebarStack` | — | `window.rb:237` |

Repeaters: none. Conditional: `headerStop` visible only while recording;
`sidebarStack`/`sidebarHeader` only when Statistics is ticked; `errorBarDetails`
only when a secondary message exists.

## Unit: welcome page — `bustle.ui`▸`InstructionsPage`

| Widget | × | CSS | Port |
|---|---:|---|---|
| `Gtk.Box` (valign center) | 1 | — | `Adwaita::StatusPage`, `welcome_page.rb:20` |
| `Gtk.Image` | 1 | `dim-label`, icon `org.freedesktop.Bustle-symbolic` | status-page `icon_name`, `welcome_page.rb:22` |
| `Gtk.Label` "Welcome to Bustle" | 1 | `dim-label`, weight bold, scale 2 | status-page `title`, `welcome_page.rb:23` |
| `Gtk.Label` instructions | 1 | `dim-label`, markup | `welcome_page.rb:31` |

## Unit: please-hold page — `bustle.ui`▸`PleaseHoldPage`

One `Gtk.Label` with its markup inside the msgid. Port adds a `Gtk::Spinner`
(`please_hold_page.rb:51`) — an **explained extra**: upstream's spinner for
this state lives in the header bar, and the port keeps that one too, so the
state has two spinners where upstream has one.

## Unit: statistics sidebar — `StatisticsPane.hs` + `bustle.ui`▸`sidebarStack`

| Widget | × | Detail | Port |
|---|---:|---|---|
| `Gtk.Stack` `sidebarStack` | 1 | 3 titled pages: Frequencies, Durations, Sizes | `statistics_pane.rb:112` |
| `Gtk.ScrolledWindow` | 3 | `frequencySW`, `durationSW`, `sizeSW` | `statistics_pane.rb:120-124` |
| `Gtk.TreeView` | 3 | headers visible, `ListStore`-backed | `Gtk::ColumnView` ×3 + `Gio::ListStore` ×3, `statistics_pane.rb:126-134` |
| `Gtk.CellRendererText` | 10 | all at `cellTextSizePoints := 7` | one `Gtk::Label` per cell factory; the 7pt is re-expressed as CSS, `statistics_pane.rb:37-41` |
| `Gtk.CellRendererToggle` | 0 | — | — |
| `Gtk.CellRendererProgress` | 1 | `2 + count*98/max`, text = count | `Gtk::ProgressBar`, `statistics_pane.rb:265` |
| columns | 10 | Member/Frequency; Method/Total/Calls/Mean; Member/Smallest/Mean/Largest | 10, `statistics_pane.rb:136-186` |

## Unit: details pane — `DetailsView.hs` + `bustle.ui`▸`detailsGrid`

| Widget | × | name / CSS | Port |
|---|---:|---|---|
| `Gtk.Grid` `detailsGrid` | 1 | — | `Gtk::Box` + `Adwaita::PreferencesGroup`, `details_view.rb:57,67` |
| `Gtk.Label` captions | 6 | `dim-label` — Type, Path, Member, Arguments, Sender, Destination | 5 `Adwaita::ActionRow` titles + 1 `heading` label, `details_view.rb:69-82` |
| `Gtk.Label` values | 4 | names `detailsPath`, `detailsMember`, `detailsSender`, `detailsDestination` | the rows' subtitles, `subtitle_selectable`, `details_view.rb:179-186` |
| `Gtk.Stack` `detailsType` | 1 | 5 pages: `methodCall`, `methodReturn`, `error`, `signal`, `directedSignal` | collapsed to one row subtitle, `details_view.rb:122-133` |
| `Gtk.TextView` `detailsArguments` | 1 | monospace body | `details_view.rb:94` |
| `Gtk.ScrolledWindow` | 1 | — | `details_view.rb:86` |

Conditional: `detailsDestination` + `detailsDestinationCaption` hidden for a
broadcast signal (`DetailsView.hs:106-112`); the port hides the whole row
(`details_view.rb:118`).

## Unit: canvas — `UI/Canvas.hs` + `bustle.ui`▸`diagramLayout`

| Widget / controller | × | Behaviour | Port |
|---|---:|---|---|
| `Gtk.Layout` `diagramLayout` | 1 | hand-translated Cairo, partial invalidation | `Gtk::DrawingArea` in a `Gtk::ScrolledWindow`, `canvas.rb:79,86` |
| `keyPressEvent` ×2 | 2 | Left/Right = one step, space = one page, Up/Down/Home/End = move selection | `Gtk::EventControllerKey`, `canvas.rb:93,113-125` |
| `buttonPressEvent` | 1 | left button only, grab focus, select by y | `Gtk::GestureClick` button 1, `canvas.rb:93,44` |
| `draw` | 1 | highlight stripe then shapes, clipped to the visible rect | `canvas.rb:41,184` |
| `Gtk.Adjustment` | 2 | **step increment set to `eventHeight`** (`Canvas.hs:102-103`) | **no counterpart** — `canvas.rb:131` reads the default |

## Unit: filter dialog — `UI/FilterDialog.hs`

| Widget | × | Detail | Port |
|---|---:|---|---|
| `Gtk.Dialog` | 1 | no title, parent·7/8 × parent/2 | `Adwaita::Window`, `filter_dialog.rb:68` |
| Close button | 1 | `stockClose`; closing applies the filter | `filter_dialog.rb:80`, `suggested-action` |
| `Gtk.Label` instructions | 1 | markup, size request 600×−1 | `filter_dialog.rb:96` — no size request |
| `Gtk.TreeView` | 1 | **rules hint on**, headers off, size request 600×371 | `Gtk::ListBox` `boxed-list`, `filter_dialog.rb:114` — none of the three |
| `Gtk.CellRendererToggle` | 1 | per-row tick | `Gtk::CheckButton` per row, `filter_dialog.rb:170` |
| `Gtk.CellRendererText` | 1 | `formatNames`: `ns{A,B}` brace compression | `filter_dialog.rb:120-155` |
| `Gtk.ScrolledWindow` | 1 | policy automatic/automatic | `filter_dialog.rb:104` |

## Unit: open-a-pair dialog — `OpenTwoDialog.ui` + `.hs`

| Widget | × | Behaviour | Port |
|---|---:|---|---|
| `Gtk.Dialog` `openTwoDialog` | 1 | `delete-event` hides and is reused | `Adwaita::Window`, rebuilt per activation, `open_two_dialog.rb:62` |
| `Gtk.FileChooserButton` | 2 | `file-set`→sensitivity; `current-folder-changed`→propagate both ways | `Gtk::Button` + `Gtk::FileDialog` ×2, `open_two_dialog.rb:186`; folder propagated only on a chosen file |
| `Gtk.Button` cancel / open | 2 | Open insensitive until both chosen | `open_two_dialog.rb:79,83` |
| `Gtk.Table` + 2 `Gtk.Label` | 3 | "Session bus log:", "System bus log:" | `Adwaita::PreferencesGroup` + 2 `ActionRow`, `open_two_dialog.rb:93,105` |

## Unit: record-address dialog — `RecordAddressDialog.ui` + `.hs`

| Widget | × | Behaviour | Port |
|---|---:|---|---|
| `Gtk.Dialog` | 1 | title "Record Address" | `Adwaita::Window`, `record_address_dialog.rb` |
| `Gtk.Entry` | 1 | `placeholder_text` (translator comment: translate only "e.g."); `changed`→Record sensitivity | `Adwaita::EntryRow`; placeholder re-expressed as the group description |
| `Gtk.Button` record / cancel | 2 | Record insensitive while empty | `record_address_dialog.rb:91` |

## Unit: menus and shortcuts — the three `GtkMenu`s

| Item | Accel | Upstream | Port action |
|---|---|---|---|
| `_Filter Visible Services…` | `Ctrl+F` | `filter` `GtkMenuItem` | `win.filter` |
| `_Statistics` | `F9` | `statistics` `GtkCheckMenuItem` | `win.statistics` (stateful boolean) |
| About | — | `about` `GtkImageMenuItem` (`gtk-about`) | `win.about`, msgid `_About Bustle` |
| Open | `Ctrl+O` | `open` `GtkImageMenuItem` (`gtk-open`) | `win.open`, msgid `_Open…` |
| `O_pen a Pair of Logs…` | — | tooltip "Display two logs—…" | `win.open-pair`; tooltip became the group description |
| `Record S_ession Bus` | `Ctrl+E` | | `win.record-session` |
| `Record S_ystem Bus` | `Ctrl+Y` | | `win.record-system` |
| `Record _Address…` | `Ctrl+A` | | `win.record-address` |
| Save | `Ctrl+S` | on `headerSave` | `win.save` |
| Export | — | none upstream | `win.export-pdf` |
| separator | — | 1 `GtkSeparatorMenuItem` | section boundary in `main_menu` |

All 7 upstream accelerators are present (`menus.rb:30-40,46`). Upstream's
`GtkMenu`/`GtkMenuItem` tree becomes `Gio::Menu` + window actions — upstream's
own comment at `UI.hs:534-538` says that is the rewrite it wanted.

## Unit: application and CLI

| Upstream | Port |
|---|---|
| `uiMain`/`mainB`, `windows` counter, `maybeQuit` | `application.rb:35-40`; `Gtk::Application` does the counting |
| `initialWindow` / `consumeInitialWindow` / `putInitialWindow` | `application.rb:53-68` |
| `[LOGFILE …]`, `--pair`, `--debug`, `--help` | `main.rb:19-30,60-70` |
| `--count` / `--time` / `--dot` | `noninteractive.rb:17,34,51` |
| `bustle-pcap` `-e -y -a -v -q -V -h` + one FILENAME | `pcap_cli.rb:56-66` |

## Scan-level totals

| Axis | Upstream distinct | Port distinct (`lib/`) |
|---|---:|---:|
| Widget types | 26 | 28 |
| CSS classes | 9 | 12 |
| Signals | 1 (the rest are in Haskell, which the scanner cannot read) | 14 |
| Actions | 0 | 11 |

The upstream signal count is a scanner limit, not a finding: upstream wires
every handler in Haskell with `on`/`onMenuItemActivate`, which
`component-scan.sh` does not match. Every upstream signal in the tables above
was read off the source by hand.

## Stylesheet

Neither tree ships a `.css` file. Upstream styles entirely with platform
classes plus GtkBuilder `<property name="name">` element names
(`errorBarTitle`, `detailsPath`, `detailsMember`, `detailsArguments`, and the
five `detailsType` page names) which no stylesheet ever defines — they are
dead. The port adds one stylesheet, a Ruby heredoc at
`statistics_pane.rb:37-41` loaded with `provider.load(data:)`, carrying the one
rule that replaces `cellTextSizePoints := 7`. The port also attaches
`property` (`details_view.rb:184`) and `data-table`
(`statistics_pane.rb:206`), both libadwaita platform classes, so neither needs
a rule.
