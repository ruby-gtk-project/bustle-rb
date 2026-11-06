# Component identification — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` (Haskell + GTK3, widget trees in GtkBuilder XML) |
| Port | `ruby` @ `732e6bb` (re-audited; previous ledger below was written for `6e6fccb`, and `.reports/component-inventory.md` was separately refreshed at `42422c4`) |
| Method | `component-identification` skill, Steps 1–5 |
| Scans | `component-scan.sh` run on both trees in the fork's dev shell |
| Symbol table | **not built** — `gir-symbols.sh` was not run, so every namespaced match stayed `widget` and the strikes below were made by reading |

Upstream's declarative UI is three GtkBuilder files read with `builderAddFromFile`:
`data/bustle.ui`, `data/OpenTwoDialog.ui`, `data/RecordAddressDialog.ui`. None of
them uses `<template>`; they declare top-level named objects fetched by id through
`builderGetObject`, so the unit list is the set of ids each Haskell module grabs.
There is no GSettings schema, no GResource manifest and no blueprint anywhere in
upstream. The port has no `.ui` files — widgets are memoized methods, per the
`ruby-gtk` house style — which the `component-parity` skill lists as a
correspondence rather than a gap.

## Totals

| Axis | Upstream | Port |
|---|---:|---:|
| Scan rows | 45 | 117 |
| `widget` rows (distinct type × file) | 35 | 62 |
| Widget instances | 93 | 82 |
| Distinct widget types | 26 | 27 |
| `css` attachment sites | 19 | 14 |
| `signal` rows | 2 (both in `c-sources/bustle-pcap.c`) | 16 rows, 25 sites |
| `action` rows | 0 | 2 |
| User-facing components | 22 | 22 |

The two signal rows upstream are the only ones a regex can see: gtk2hs connects
with `` `on` `` and a Haskell function name, not with a quoted signal string, so
the whole behaviour axis on the upstream side was read out of the source by hand.
The port's `action` stream is likewise unusable — `header_bar.rb` yields
`win.export-pdf` and a bare `win.`, because the save button's name is built by
interpolation — so the ten window actions were read off `menus.rb:24-33`.

## Unit list

Twenty-two user-facing components, in the order a user meets them. Each row names
the upstream file(s) unioned before comparison and the port file opposite them.
Detail per component, with the four axes compared, is in
`.reports/component-parity.md`.

| # | Component | Upstream | Port |
|---:|---|---|---|
| 1 | the application | `Bustle.hs` + `UI.hs`▸`uiMain`/`mainB` | `lib/bustle/application.rb`, `lib/bustle/main.rb` |
| 2 | the main window | `bustle.ui`▸`diagramWindow` + `UI.hs`▸`emptyWindow`/`displayLog`/`setPage` | `lib/bustle/window.rb` |
| 3 | the header bars | `bustle.ui`▸`header`, `headerPaned`, `sidebarHeader` | `lib/bustle/header_bar.rb` |
| 4 | menus, actions, shortcuts | `bustle.ui`▸`filterStatsEtc`, `openMenu`, `recordMenu` + `onMenuItemActivate` sites | `lib/bustle/menus.rb` |
| 5 | the error state | `bustle.ui`▸`errorBar`/`errorBarTitle`/`errorBarDetails` + `displayError`/`hideError` | `lib/bustle/error_bar.rb` |
| 6 | the empty state | `bustle.ui`▸`InstructionsPage` | `lib/bustle/welcome_page.rb` |
| 7 | the waiting page | `bustle.ui`▸`PleaseHoldPage` | `lib/bustle/please_hold_page.rb` |
| 8 | the diagram canvas | `UI/Canvas.hs` + `bustle.ui`▸`diagramLayout`/`scrolledwindow1` | `lib/bustle/canvas.rb` |
| 9 | the details pane | `UI/DetailsView.hs` + `bustle.ui`▸`detailsGrid` | `lib/bustle/details_view.rb` |
| 10 | the statistics sidebar | `StatisticsPane.hs` + `bustle.ui`▸`sidebarStack`/`frequencySW`/`durationSW`/`sizeSW` | `lib/bustle/statistics_pane.rb` |
| 11 | the service filter dialog | `UI/FilterDialog.hs` | `lib/bustle/filter_dialog.rb` |
| 12 | open a pair of logs | `UI/OpenTwoDialog.hs` + `OpenTwoDialog.ui` | `lib/bustle/open_two_dialog.rb` |
| 13 | record an arbitrary address | `UI/RecordAddressDialog.hs` + `RecordAddressDialog.ui` | `lib/bustle/record_address_dialog.rb` |
| 14 | open one log | `UI.hs`▸`showOpenDialog` | `lib/bustle/open_dialog.rb` |
| 15 | export as PDF | `UI.hs`▸`saveToPDFDialogue` | `lib/bustle/pdf_export.rb` |
| 16 | the recording flow | `UI/Recorder.hs` + `UI.hs`▸`startRecording`/`recorderRun`/`processBatch`/`finishedRecording` | `lib/bustle/recorder.rb` |
| 17 | unsaved-recording confirmation | `UI.hs`▸`promptToSave` | `lib/bustle/window.rb`▸`save_prompt` |
| 18 | the about dialog | `UI/AboutDialog.hs` | `lib/bustle/about_dialog.rb` |
| 19 | the batch CLI modes | `Noninteractive.hs` | `lib/bustle/noninteractive.rb` |
| 20 | the `bustle-pcap` binary | `c-sources/bustle-pcap.c` | `lib/bustle/pcap_cli.rb`, `exe/bustle-pcap` |
| 21 | the live bus monitor | `Monitor.hs` + `c-sources/pcap-monitor.c` | `lib/bustle/monitor.rb` |
| 22 | data files and catalogue | `data/*.in`, `data/icons/**`, `po/` | same shape, renamed app id |

Components 17 and 20 are each one upstream file split or merged: `promptToSave`'s
alert dialog lives inside `window.rb` and `recorderChooseFile`'s save chooser
inside `recorder.rb`, which is where upstream puts them too (neither is a widget
class upstream). That is a mapping fact, not a gap.

## Upstream is GTK3, so the widget axis cannot be diffed on type

Nine of upstream's 26 widget types have no GTK4 counterpart at all, which is why
the comparison in `component-parity.md` is carried on the CSS, signal, action and
text axes with each substitution named:

| Upstream (GTK3) | × | Port |
|---|---:|---|
| `Gtk.Menu`, `Gtk.MenuItem`, `Gtk.ImageMenuItem`, `Gtk.CheckMenuItem`, `Gtk.SeparatorMenuItem` | 3 + 5 + 2 + 1 + 1 | `Gio::Menu` models + `Gio::SimpleAction`s (`menus.rb`) |
| `Gtk.InfoBar` + `Gtk.ButtonBox` | 1 + 3 | `Gtk::Box` in the error colours + a flat close button (`error_bar.rb`) |
| `Gtk.Layout` | 1 | `Gtk::DrawingArea` inside a `Gtk::ScrolledWindow` (`canvas.rb`) |
| `Gtk.Table` | 1 | `Adwaita::PreferencesGroup` + `Adwaita::ActionRow` (`open_two_dialog.rb`) |
| `Gtk.FileChooserButton` | 2 | `Gtk::Button` opening a `Gtk::FileDialog` (`open_two_dialog.rb`) |
| `Gtk.Dialog` | 2 | `Adwaita::Window` with the buttons in its header bar |
| `Gtk.Grid` | 1 | `Adwaita::PreferencesGroup` of `Adwaita::ActionRow`s (`details_view.rb`) |
| `Gtk.TreeView` (built in Haskell, not in the `.ui`) | 4 | `Gtk::ColumnView` ×3, `Gtk::ListBox` ×1 |
| `Gtk.Entry` | 1 | `Adwaita::EntryRow` (`record_address_dialog.rb`) |

## What the scan under-reports, read by hand

- **Four tree views are not in any `.ui` file.** `StatisticsPane.hs:130-226` builds
  three `TreeView`s with hand-written cell renderers, and
  `FilterDialog.hs:60-99` a fourth. None of them produces a scan row, because the
  construction is `treeViewNewWithModel`.
- **Ten window actions, none of them a literal in the stream.** `menus.rb:24-33`
  loops over a hash: `open`, `open-pair`, `record-session`, `record-system`,
  `record-address`, `save`, `filter`, `export-pdf`, `about`, plus the stateful
  `statistics`. Upstream has no actions at all; `UI.hs:540` says the app menu
  "entails binding GApplication, GtkApplication, GMenu, GActionMap, GActionEntry,
  ..." and declines, so the accelerators live on the GtkMenuItems.
- **Seven accelerators**, all from `bustle.ui`: Ctrl+F (`:16`), F9 (`:26`), Ctrl+O
  (`:55`), Ctrl+E (`:77`), Ctrl+Y (`:86`), Ctrl+A (`:95`), Ctrl+S (`:335`).
  `openTwo`, `about` and `headerExport` carry none.
- **Repeaters.** `filter_dialog.rb:68` appends one `Adwaita::ActionRow` per bus
  participant; `statistics_pane.rb:208` appends one row per statistics record ×3
  tables. One component each, variable count.
- **Factories, not widgets.** `statistics_pane.rb` has four
  `Gtk::SignalListItemFactory`s whose `setup` blocks build the real cells — a
  `Gtk::Box` with two `Gtk::Label`s, a right-aligned `Gtk::Label`, and a
  `Gtk::ProgressBar`. Those are 4 scan rows and N×4 widgets on screen.
- **Dynamic CSS.** Nothing in the port adds a class conditionally; every
  `add_css_class` site is unconditional, so the `css` stream is complete for the
  port side.
- **Three stylesheets built in Ruby, not as `.css` files.** `error_bar.rb:28-33`,
  `statistics_pane.rb:52-57` and `filter_dialog.rb:33-37` each hold a heredoc
  loaded with `provider.load(data:)`. `find -name '*.css'` is empty on both sides;
  upstream ships no stylesheet at all.
- **Controllers.** `canvas.rb` attaches a `Gtk::GestureClick` and a
  `Gtk::EventControllerKey`, which stand in for upstream's `buttonPressEvent` and
  two `keyPressEvent` handlers. Compared on the signal axis, not the widget axis.

## Non-widget modules

One `lib/*.rb` per upstream module, with no file missing in either direction:
`Diagram.hs`→`diagram.rb`, `Renderer.hs`→`renderer.rb`, `Regions.hs`→`regions.rb`,
`Stats.hs`→`stats.rb`, `Types.hs`→`types.rb`, `Marquee.hs`→`marquee.rb`,
`Loader.hs`→`loader.rb`, `Loader/Pcap.hs`→`pcap_loader.rb`,
`VariantFormatter.hs`→`variant_formatter.rb`, `Util.hs`→`util.rb`,
`Missing.hs`→`missing.rb`, `src-hgettext/Bustle/Translation.hs`+`GetText.hs`→
`translation.rb`. `Bustle/Application/Monad.hs` has no port file: it is the
`ReaderT`/`StateT` stack Haskell needs to thread `BConfig`/`BState`, and its
content is `Application`'s and `Window`'s own instance state.

`Test/DumpMessages.hs` is a cabal `Executable`, not a test or a component; it
asserts nothing and its printing loop is commented out upstream.

## Non-component upstream files with no port counterpart

| Upstream | Port | State |
|---|---|---|
| `README.md` — describes what Bustle is, how to build it, how to record | `README.md`, whose `## 🌻 Synopsis` heading is **empty** and whose only two mentions of Bustle are the gem name and the licence badge | **gap** |
| `INSTALL.md`, `NEWS.md`, `CONTRIBUTING.md` | `CHANGELOG.md` carries the release notes; no install or contributing guide of its own | gap, documentation only |
| `flatpak/org.freedesktop.Bustle.yaml`, `flatpak/Makefile` | — | gap, packaging only |
| `.gitlab-ci.yml` | GitHub workflows from the gem template | correspondence |

These are outside the 22 components and outside the four axes, and they are
recorded here because nothing else in the repository records them.

## Re-audit at `732e6bb` (2026-11-06)

Re-counted rather than re-read: `find lib exe -name '*.rb'` still returns 36
files, matching the file-mapping table above with no new or removed upstream
source file on either side (`git ls-tree -r --name-only origin/master`
re-diffed against `PORTING.md`'s architecture table, no new row either way).
`README.md`'s empty `## 🌻 Synopsis` — noted above as a non-component gap in
the previous round's identification pass — is closed; the heading now carries
three paragraphs of real content, confirmed by reading the current file, not
by trusting `PORTING.md`'s claim that it was fixed. The symbol table
(`gir-symbols.sh`) is still not built, unchanged from the previous round.
