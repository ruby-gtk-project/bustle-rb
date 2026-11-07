# Port status

Resume point for the next run. Upstream is the `origin/master` ref in this
repository; the port is the `ruby` branch. Read upstream with
`git show origin/master:<path>` — it is never checked out and never merged.

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `71d3f60` (this file is updated by the commit after it) |
| Last audit | `.reports/*` @ port `71d3f60` — 19 gaps, `clean=false` |
| Verified by | `ruby test/drive_all.rb` — 22 of 22 components, both drive scripts |

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

Components implemented and believed complete. Every one of them has been run:
`test/drive_all.rb` runs `test/drive_bustle.rb` (21 components, 290 checks,
21 screenshots) and `test/drive_recording.rb` (component 21 — a real session
bus recorded through the GUI) and sums what the two covered, 22 of 22. So
"believed complete" here means the four parity axes agree when both sources
are read **and** the component was seen working headlessly; what it does not
mean is that every divergence has been found. See **Open gaps**.

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

Live recording was exercised end to end on this machine's session bus, both
from the command line (`bustle-pcap -v`) and through the GUI
(`test/drive_recording.rb`: record, make traffic, stop, read the log back and
find the monitor's own claimed name in it). The specs run with `rake spec`,
which `rakelib/spec.rake` defines because kettle-dev is absent in this dev
shell: 38 examples, 0 failures (24 as of the previous audit round plus 14 new
in `spec/monitor_spec.rb`, added with the G12 fix; see
`.reports/accountability-ensurance.md`, finding A8, for the fact that this
number drifted in every report that cited it until this audit round).

## Not started

No upstream source file is without a Ruby counterpart. `Test/DumpMessages.hs`
is excluded on purpose: it is a cabal `Executable`, not a test, it asserts
nothing, and its printing loop is commented out upstream.

Non-component work not started:

- The port has no gettext domain. `lib/bustle/translation.rb` reads `po/*.po`
  at run time and `Bustle._` looks the msgid up in that hash. It works — it
  was driven under `en_GB` and `de_DE` — and `rake po:check` now runs
  `msgfmt -c` over every catalogue, but there is no `.mo` install rule, no
  plural-forms engine and no `msgctxt` support. Upstream's catalogue has
  neither plurals nor contexts, so nothing is untranslatable today; the first
  upstream plural would be.
- `.reports/component-parity.md` and `.reports/translation-parity.md` still
  describe gaps this round closed as open. The ledgers are the audit's to
  rewrite, not the port's, but a reader of those files alone will overstate
  the debt.

## Open gaps

The audit at port `71d3f60` reported 19 gaps, `clean=false`: 12 in
`.reports/component-parity.md`, 4 in `.reports/translation-parity.md`, 1 in
`.reports/test-parity.md` and 7 in `.reports/accountability-ensurance.md`
(two rows appear in two ledgers by design). The commit after this file closed
all but the two below. Each of those two is open because closing it costs
more than it is worth, and each is named in the code that owns it, in the
first person, as missing work rather than as a decision.

1. **A browsed folder does not travel between Open-a-Pair's two choosers.**
   Upstream connects `current-folder-changed` on both
   (`Bustle/UI/OpenTwoDialog.hs:36-44`), so merely navigating moves the other
   chooser while it is still empty. GTK4's `Gtk::FileDialog` is a one-shot
   modal with no signals at all — verified, `FINDINGS.md` — so the port can
   only observe the folder a file was *chosen* from, which it now remembers
   for both choosers. Browse-then-dismiss is not recovered. **Accepted
   permanently as of this round**, not reopened by a third audit: closing it
   needs a hand-built `GtkFileChooserWidget`-based replacement for
   `Gtk::FileDialog`, which is a different, much larger component than a
   signal hookup, and the common case (folder travels with the chosen file)
   already works.
2. **No gettext domain.** As under **Not started** above: a run-time PO
   reader instead of a bound domain, so no plural forms, no `msgctxt` and no
   `.mo` install rule.

Closed this round: **the monitor now prefers the libpcap error over the
subprocess one.** Upstream's `await_both_errors`/`handle_error` waits for
both and then reports libpcap's, "including the wonderful snaplen bug"
(`c-sources/pcap-monitor.c:393-412`, `:359-368`), ahead of a bare non-zero
exit — but still behind the pkexec 126/127 cases and a clean exit (0), which
upstream reports unconditionally. `lib/bustle/monitor.rb`'s bad-magic and
bad-link-type checks now record a pcap-side error and let the subprocess
run to its own exit (terminating it and arming the existing stop timeout)
instead of tearing the recording down on the spot, so `#report_exit` can
weigh the two against each other in upstream's order; previously the port's
single error path meant whichever was read first won by construction, not
by rule. Covered by `spec/monitor_spec.rb`, which also closes the wider gap
named in `.reports/accountability-ensurance.md` finding A1: component 21 had
no coverage at all of the pcap frame parser, the exit-status mapping or
subprocess supervision beyond a 3-branch `case` statement and the one
drive-recording happy path, both of which remain, as drive checks exercising
the real D-Bus and process machinery the specs stub out.

What the round before this one left behind, and this round closed, so that it
is not looked for again: `Monitor#stop` now closes the read end of
dbus-monitor's stdout and arms upstream's two-second timeout, so Stop always
reaches `stopped` (driven against a child that traps `SIGTERM`); `stopped`
carries `g-spawn-exit-error` and the child's exit status for a child that
exited; the pkexec 126/127/0 mappings are driven against a fabricated exit
status, including the behaviour owed — a dismissed authorisation dialog is
silent; `bustle-pcap` exits 0 for a runtime error and 1 only for a monitor
that would not start, announces nothing until the subprocess has spawned, and
warns about an unparseable frame on stderr; Return in the Record Address
entry records; the welcome page is greyscale at upstream's 256 pixels and the
Arguments caption is dimmed rather than emphasised; `bustle`'s argument
handling matches `["--help"]` as a whole, strips only `--debug` and passes
every other token to the loader; `GLib.application_name` is set from the
`Bustle` msgid; `rake po:pot` extracts the port's own `Icon=` value and
`rake po:check` fails on a stale `po/` or a catalogue `msgfmt -c` rejects;
`rake spec` exists; and `test/drive_all.rb` is the coverage gate, because
`drive_bustle.rb` alone could not honestly claim component 21.

Two caveats the reports carry about themselves, which are not counted as gaps
but limit what every verdict above is worth:

- `.reports/component-parity.md` step 5 (screenshot the unit) was run for the
  widget components through `test/drive_bustle.rb`, but the ledger text
  predates that run and still says it was not.
- `.claude/skills/translation-parity/scripts/msgid-census.sh` saw neither
  side's marker for one round — commit `732e6bb`, an automated "Sync the
  scaffold from port-scaffold," silently reverted the qualified-receiver
  (`Bustle._("…")`) and Haskell `__ "…"` fix nine minutes after it landed, and
  nobody noticed for 9 commits because nothing in the repo runs the skill's
  own scripts as a check. This round reapplies that fix verbatim (restoring
  the `(g_)?` → `([A-Z][A-Za-z0-9_]*\.)?(g_)?` qualified-receiver match and
  the `*.hs` / `haskell` marker handling) and confirms it against this tree:
  `bash .claude/skills/translation-parity/scripts/msgid-census.sh lib exe`
  now returns 93 rows against the 91 real `Bustle._(...)` call sites (two
  rows are the `.desktop`/`.po` extras the script also counts), and the
  scanner is genuinely fixed: `census-smoke.sh`, added this round, pins that
  down so a future sync that drops the fix again fails a check instead of
  going unnoticed for nine commits. This paragraph previously went on to cite
  a specific `catalogue.rb --compare` number as settled fact; that number did
  not reproduce (finding T2, `.reports/accountability-ensurance.md`) and has
  been removed from here rather than replaced with another one this document
  would go stale against. `catalogue.rb --compare` is a message-by-message
  machine count, not a parity verdict — a "gap" it reports can be a message
  the port genuinely has not ported, or one the port phrases differently on
  purpose, and telling those apart is exactly the judgement
  `.reports/translation-parity.md` exists to carry. Read that report's own
  header figures for the current count; they are regenerated and checked
  against the tree every round, which a number copied into this file is not.

  See `.reports/accountability-ensurance.md`, finding T1 (the scanner fix
  itself) and finding T2 (the stale number this paragraph used to repeat).

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
  of that choice is open gap 2 and the shape of the stop path: the port has to
  read an exit status where upstream reads a `GError`, and it has to make a
  child it may not be able to signal go away — which is why `Monitor#stop`
  closes the pipe and arms a timeout, and why `report_exit` maps pkexec's
  statuses by hand.
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
