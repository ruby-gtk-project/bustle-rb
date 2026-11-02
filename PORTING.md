# Port status

Resume point for the next run. Upstream is the `origin/master` ref in this
repository; the port is the `ruby` branch. Read upstream with
`git show origin/master:<path>` — it is never checked out and never merged.

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `d7a5a16` (this file is the commit after it) |
| Last audit | `.reports/*` @ port `16f6787` — 14 gaps, `clean=false` |

## Upstream

Bustle records D-Bus traffic — session bus, system bus, or an arbitrary bus
address — into a pcap-format log, or loads one off disk, and draws it as an
interactive sequence diagram with a per-message details pane, a statistics
sidebar, a service filter and PDF export.

It is implemented in Haskell (gtk2hs / GTK 3), with GtkBuilder `.ui` files for
the widget tree and one C GObject (`c-sources/pcap-monitor.c`) for the pcap
monitor. 45 widgets across three `.ui` files; the Haskell builds almost
nothing directly. 23 tests in three cabal `Test-suite` stanzas (QuickCheck
properties plus HUnit cases). One `po/en.po` and a committed
`po/messages.pot`; no GSettings schema and no GResource manifest.

## Done

Components implemented and believed complete. "Believed complete" means the
four parity axes agree when both sources are read — not that the behaviour was
observed. Nothing with a widget in it has ever been run; see **Open gaps**.

| Port | Upstream |
|---|---|
| `lib/bustle/window.rb` | `Bustle/UI.hs` + `data/bustle.ui`▸`diagramWindow` |
| `lib/bustle/header_bar.rb` | `data/bustle.ui`▸`header`, `sidebarHeader` |
| `lib/bustle/error_bar.rb` | `data/bustle.ui`▸`errorBar` |
| `lib/bustle/welcome_page.rb` | `data/bustle.ui`▸`InstructionsPage` |
| `lib/bustle/please_hold_page.rb` | `data/bustle.ui`▸`PleaseHoldPage` |
| `lib/bustle/menus.rb` | `data/bustle.ui`▸`openMenu`, `recordMenu`, `filterStatsEtc` |
| `lib/bustle/canvas.rb` | `Bustle/UI/Canvas.hs` + `bustle.ui`▸`diagramLayout` |
| `lib/bustle/details_view.rb` | `Bustle/UI/DetailsView.hs` + `bustle.ui`▸`detailsGrid` |
| `lib/bustle/statistics_pane.rb` | `Bustle/StatisticsPane.hs` + `bustle.ui`▸`sidebarStack` |
| `lib/bustle/filter_dialog.rb` | `Bustle/UI/FilterDialog.hs` |
| `lib/bustle/open_dialog.rb` | `Bustle/UI.hs`▸open/save/export choosers |
| `lib/bustle/open_two_dialog.rb` | `Bustle/UI/OpenTwoDialog.hs` + `data/OpenTwoDialog.ui` |
| `lib/bustle/record_address_dialog.rb` | `Bustle/UI/RecordAddressDialog.hs` + `data/RecordAddressDialog.ui` |
| `lib/bustle/about_dialog.rb` | `Bustle/UI/AboutDialog.hs` |
| `lib/bustle/recorder.rb` | `Bustle/UI/Recorder.hs` + `UI.hs`▸recording half |
| `lib/bustle/monitor.rb` | `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` |
| `lib/bustle/pcap_cli.rb`, `exe/bustle-pcap` | `c-sources/bustle-pcap.c` |
| `lib/bustle/main.rb`, `exe/bustle` | `Bustle.hs` |
| `lib/bustle/application.rb` | `Bustle/Application/Monad.hs` + `UI.hs`▸`uiMain`/`mainB` |
| `lib/bustle/noninteractive.rb` | `Bustle/Noninteractive.hs` |
| `lib/bustle/pdf_export.rb` | `Bustle/UI.hs`▸`saveToPDFDialogue` + `Diagram.hs` surface setup |
| `lib/bustle/loader.rb` | `Bustle/Loader.hs` |
| `lib/bustle/pcap_loader.rb` | `Bustle/Loader/Pcap.hs` |
| `lib/bustle/renderer.rb` | `Bustle/Renderer.hs` |
| `lib/bustle/diagram.rb` | `Bustle/Diagram.hs` |
| `lib/bustle/regions.rb` | `Bustle/Regions.hs` |
| `lib/bustle/stats.rb` | `Bustle/Stats.hs` |
| `lib/bustle/types.rb` | `Bustle/Types.hs` |
| `lib/bustle/marquee.rb` | `Bustle/Marquee.hs` |
| `lib/bustle/missing.rb` | `Bustle/Missing.hs` |
| `lib/bustle/util.rb` | `Bustle/Util.hs` |
| `lib/bustle/variant_formatter.rb` | `Bustle/VariantFormatter.hs` |
| `lib/bustle/translation.rb` | `src-hgettext/Bustle/Translation.hs` |
| `spec/regions_spec.rb` | `Test/Regions.hs` (14 QuickCheck properties) |
| `spec/renderer_spec.rb` | `Test/Renderer.hs` (8 cases) |
| `spec/pcap_loader_spec.rb` | `Test/PcapCrash.hs` (1 case) |
| `po/`, `data/*.in`, `rakelib/translation.rake` | `po/`, `data/*.in`, `Makefile` gettext rules |

Live recording was exercised end to end on this machine's session bus:
`bustle-pcap -v /tmp/rec.bustle` logged two messages, stopped cleanly on
`SIGINT`, and the port's own `PcapLoader` read the file back. All 23 ported
specs pass against the real `lib/`, executed with a throwaway RSpec stand-in
because `rspec` is not installed in this checkout.

## Not started

No upstream source file is without a Ruby counterpart. `Test/DumpMessages.hs`
is excluded on purpose: it is a cabal `Executable`, not a test, it asserts
nothing, and its printing loop is commented out upstream.

Non-component work not started:

- `README.md` is still the unedited gem template. It does not mention D-Bus,
  Bustle, or what the application does.
- No screenshot or run-time verification exists for any widget file. `ruby -c`
  is all that has been applied to `window.rb`, `header_bar.rb`, `canvas.rb`,
  `statistics_pane.rb`, `details_view.rb`, `filter_dialog.rb`,
  `record_address_dialog.rb` and `recorder.rb`.

## Open gaps

14 gaps, `clean=false`, from the audit at port `16f6787`: 12 in
`.reports/component-parity.md`, 1 in `.reports/translation-parity.md`, and 1
load-bearing excuse in `.reports/accountability-ensurance.md`.
`.reports/test-parity.md` reports 0 gaps.

Component gaps, as that report ranks them by cost to close:

1. Live recording never seeds well-known-name ownership. Upstream's
   `pcap-monitor.c:415-456` runs `ListNames` and one `GetNameOwner` per
   well-known name on a second connection; `monitor.rb` opens no D-Bus
   connection at all. `pcap_loader.rb:433-440` already turns a `GetNameOwner`
   reply into a name-ownership event, so the machinery exists and is never
   fed. Consequence: every service already on the bus when recording starts is
   drawn as a bare unique name (`:1.42`) where upstream draws
   `org.gnome.Shell`, and the filter dialog lists unique names. Logs recorded
   by upstream's `bustle-pcap` display correctly; logs recorded by this port
   do not.
2. `pkexec` exit 126 (dialog dismissed), exit 127 (not authorized) and exit 0
   (bus shut down) are not mapped to upstream's `G_IO_ERROR_CANCELLED` /
   `G_IO_ERROR_PERMISSION_DENIED` / silent-cancellation outcomes.
   `monitor.rb:271-278` never reads the exit status and reports raw stderr. A
   dismissed polkit prompt therefore shows an error upstream swallows. Also
   in this row: libpcap errors have no precedence over subprocess errors.
3. The monitor owns no `org.freedesktop.Bustle.Monitor.<unique>` name, so the
   viewer cannot hide the monitor's own traffic (`pcap-monitor.c:31`, `:530`).
4. `bustle-pcap` rejects `--address=X`, bundled short options (`-vq`) and
   abbreviated long options (`--sess`), all of which GOption accepts
   upstream. `pcap_cli.rb:105-123` matches exact tokens only. A script running
   `bustle-pcap --address=unix:path out.pcap` works against upstream and exits
   2 here.
5. `bustle-pcap` rejects a repeated bus flag (`-e -e` is one bus upstream),
   and `--help` outranks a parse error, so `--help --bogus` exits 0 instead of
   2. `pcap_cli.rb:127-139`. The `--help` text is also a hand-written heredoc
   approximating GLib's output, not byte-compared.
6. The error bar is not error-coloured. `Adwaita::Banner` carries no `error`
   class against upstream's `message_type=error` (`bustle.ui:369`).
7. The error bar's title and details are not selectable. Both labels are
   `selectable` upstream on purpose (`bustle.ui:411`, `:427`) — the thing a
   user does with "Could not read '/path': …" is paste it into a bug report.
   `error_bar.rb:50,57`.
8. The canvas scroll step is not one event row. `Canvas.hs:102-103` sets
   `step_increment` on both adjustments to `eventHeight` (30.0);
   `canvas.rb:131` reads the getter and nothing sets it, so Left/Right and the
   scrollbar arrows move by GTK's default.
9. The filter list has no row banding (`treeViewSetRulesHint True`,
   `FilterDialog.hs:72`) and neither size request (600×371 on the view,
   600×−1 on the instructions). `filter_dialog.rb:96,114`.
10. Open-a-pair does not propagate a browsed folder between the two choosers;
    upstream wires `current-folder-changed` on both. `open_two_dialog.rb:133-139`.
11. The statistics Frequency column is `fixed_width = 120`, a ceiling, where
    upstream sets `setMinWidth 120`, a floor, so the progress bar cannot grow
    when the sidebar is widened. `statistics_pane.rb:145`.
12. Details values go unescaped into markup-interpreting `AdwActionRow`
    subtitles. Upstream uses `labelSetText` for sender/destination/path and
    `labelSetMarkup` only for member (`DetailsView.hs:104-114`);
    `details_view.rb:108-118` assigns raw strings to all of them.

Translation gap:

13. `org.freedesktop.Bustle` — upstream marks the `Icon=` value of its desktop
    entry translatable (`data/org.freedesktop.Bustle.desktop.in:6`,
    `po/messages.pot:248`). The port's `data/org.rubygtkproject.Bustle.desktop.in`
    does not mark its `Icon=` line, so no counterpart key is produced.
    Copying upstream's bytes would be wrong — it names an icon this port does
    not ship. Closing it means marking the port's own icon name the way
    upstream marks its own, or getting upstream's row deleted as the
    extraction bug it probably is.

Accountability gap:

14. `PORTING.md` at `16f6787` (lines 35-40) and `monitor.rb:16-19` presented
    gap 3 as a reasoned decision — a new `ruby-dbus` dependency "for a hint
    the viewer does not currently act on" — rather than as missing work. The
    audit flagged it as the one load-bearing excuse in the repository, and
    flagged that eleven of the twelve component gaps were named in no document
    at all. This file names all twelve; the sentence in `monitor.rb:16-19` has
    not been rewritten.

Two further caveats the reports carry about themselves, which are not counted
as gaps but limit what every verdict above is worth:

- `component-parity.md` step 5 was not run. No unit was screenshotted and
  `rspec` is not installed here, so "parity" in that ledger means the sources
  agree, not that the behaviour was observed firing.
- `translation-parity.md` records two defects in its own scanner (the port's
  `Bustle._("…")` marker and Haskell's `__ "…"` marker are both invisible to
  it) and `test-parity.md` one (no QuickCheck or HUnit patterns). All three
  censuses were taken by hand as a result.

## Blockers

Nothing here is blocked outright. These are the places where upstream has no
Ruby counterpart and the port had to be remodelled rather than transcribed;
each decision is recorded so the next run does not reopen it.

- **Live recording has no Ruby libpcap binding.** `Bustle/Monitor.hs` is an
  FFI shim over ~28KB of C (`c-sources/pcap-monitor.c`) that becomes a
  `BecomeMonitor` eavesdropper and writes pcap frames itself. No libpcap
  binding is in the gemset. **Resolved by:** `lib/bustle/monitor.rb` supervises
  `dbus-monitor --pcap` as a subprocess — behind `pkexec` for the system bus,
  behind `flatpak-spawn --host` inside a sandbox — and writes the pcap half in
  Ruby, emitting upstream's `message-logged` and `stopped` signals. The cost
  of that choice is gaps 1-3: a subprocess has no bus connection of its own.
- **pcap parsing needs a D-Bus unmarshaller.** `Bustle/Loader/Pcap.hs` leans
  on Haskell's `dbus` package to unmarshal wire messages. **Resolved by:**
  `lib/bustle/pcap_loader.rb` carries its own marshaller; `ruby-dbus` is not a
  dependency.
- **GTK3-only widgets with no GTK4 counterpart.** Remodellings, not
  transcriptions: `GtkLayout` → `Gtk::DrawingArea` in a `Gtk::ScrolledWindow`
  with `GestureClick` + `EventControllerKey`; `GtkTreeView`/`ListStore`/cell
  renderers including `CellRendererProgress` → `Gtk::ColumnView` +
  `SignalListItemFactory`; `GtkMenu`/`GtkMenuItem`/`GtkImageMenuItem`/
  `GtkCheckMenuItem` and stock items → `Gio::Menu` + `SimpleAction`;
  `GtkFileChooserButton` and `GtkFileChooserDialog` → async `Gtk::FileDialog`
  with no response ids; `GtkTable`; `GtkInfoBar` → `Adwaita::Banner`;
  `GtkButtonBox`; `GtkMessageDialog` → `Adwaita::AlertDialog`. Each
  substitution is located in `.reports/component-identification.md`; three of
  them are the proximate cause of gaps 6, 7 and 9.
- **The custom-titlebar paned trick is a GTK3 idiom.** Upstream binds
  `headerPaned` to `sidebarPaned` to fake a split titlebar. Under Libadwaita
  the honest shape is `Adwaita::ToolbarView` plus the sidebar paned, which
  changes the widget tree even though the UX survives.
  `Adwaita::ApplicationWindow` itself is unusable in these bindings, so the
  window is a `Gtk::ApplicationWindow`; the run that settled it is in
  `FINDINGS.md`.
- **PDF export depends on the canvas.** It needs the cairo gem's PDF surface
  plus the whole of `Diagram.hs`'s drawing code, so it could not land before
  `diagram.rb` did. Both are in place; neither has been run with a display.
- **Translations have no catalogue to carry over.** Upstream ships only
  `po/en.po`, so there are 67 translatable strings and no translated
  catalogue. They stay wrapped in `Bustle._("…")`.
- **No GSettings schema and no GResource manifest exist upstream**, so there
  is nothing to port on those axes. Their absence here is not a gap.
