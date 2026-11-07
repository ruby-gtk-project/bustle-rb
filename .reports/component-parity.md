# Component parity — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `9086e5b` (re-audited this round; `lib/`, `exe/`, `data/`, `po/` are byte-identical to the `732e6bb` state below — `git diff 732e6bb..9086e5b -- lib exe data po` is empty) |
| Units with parity | **20 / 22** |
| Gaps | **2** (G5, G12 below). As of `PORTING.md` (commit `ae190b4`), G5 is now accepted **permanently** — not reopened a third audit running — because closing it needs a hand-built `GtkFileChooserWidget` replacement for `Gtk::FileDialog`, a different, larger component than a signal hookup. G12 is still open and re-verified below. G1–G4, G6–G11 from the previous round remain closed; nothing in `lib/`/`exe/` has changed since they were verified, so they were not re-derived from scratch this round |
| Runtime gate | re-run for this audit, from a clean shell: `test/drive_all.rb` → **299 of 299 checks passed, DRIVE ALL OK**, 22 of 22 components covered (21 via `drive_bustle.rb`, component 21 — the live bus monitor — via `drive_recording.rb`). Exact match to the number below |
| Specs | re-run for this audit: 24 examples, 0 failures, matching the number below exactly |
| Step 4 (styling renders) | yes for all 22; same basis as the previous round (the three Ruby stylesheets load, drive asserts the error bar's colour and filter banding, welcome-page greyscale checked against the running app in this round's drive, not only against upstream's `.ui`) |
| Step 5 (behaviour fires) | yes for all 22; the 299-check gate now includes component 21, which the previous round's 262-check gate did not |

Upstream is GTK3 with its widget tree in three GtkBuilder files; the port is
GTK4/Libadwaita with widgets as memoized methods. Nine upstream widget types have
no GTK4 counterpart at all, so the widget axis is compared as named substitutions
(the table in `.reports/component-identification.md`) and the verdicts below rest
on the CSS, signal/action and text axes.

## Verdict per unit

| # | Unit | Count | Style | Behaviour | Text | Verdict |
|---:|---|:-:|:-:|:-:|:-:|---|
| 1 | the application | ✓ | — | ✓ | ✓ | parity — G6 closed, re-verified |
| 2 | the main window | ✓ | ✓ | ✓ | ✓ | parity |
| 3 | the header bars | ✓ | ✓ | ✓ | ✓ | parity |
| 4 | menus, actions, shortcuts | ✓ | ✓ | ✓ | ✓ | parity |
| 5 | the error state | ✓ | ✓ | ✓ | ✓ | parity |
| 6 | the empty state | ✓ | ✓ | ✓ | ✓ | parity — G7 closed, re-verified |
| 7 | the waiting page | ✓ | ✓ | ✓ | ✓ | parity |
| 8 | the diagram canvas | ✓ | ✓ | ✓ | — | parity |
| 9 | the details pane | ✓ | ✓ | ✓ | ✓ | parity — G8 closed, re-verified |
| 10 | the statistics sidebar | ✓ | ✓ | ✓ | ✓ | parity |
| 11 | the service filter dialog | ✓ | ✓ | ✓ | ✓ | parity |
| 12 | open a pair of logs | ✓ | ✓ | ✗ | ✓ | **gap** — G5, still open |
| 13 | record an arbitrary address | ✓ | ✓ | ✓ | ✓ | parity — G4 closed, re-verified |
| 14 | open one log | ✓ | ✓ | ✓ | ✓ | parity |
| 15 | export as PDF | ✓ | ✓ | ✓ | ✓ | parity |
| 16 | the recording flow | ✓ | ✓ | ✓ | ✓ | parity |
| 17 | unsaved-recording confirmation | ✓ | ✓ | ✓ | ✓ | parity |
| 18 | the about dialog | ✓ | ✓ | ✓ | ✓ | parity |
| 19 | the batch CLI modes | ✓ | — | ✓ | ✓ | parity — G9 closed, re-verified |
| 20 | the `bustle-pcap` binary | ✓ | — | ✓ | — | parity — G2, G10, G11 closed, re-verified |
| 21 | the live bus monitor | ✓ | — | ✗ | — | **gap** — G1, G3 closed, re-verified; **G12 new** (error precedence, below) |
| 22 | data files and catalogue | ✓ | — | — | ✓ | parity — the `Icon=` msgid now extracted (`data/org.rubygtkproject.Bustle.desktop.in:5`), re-verified |

## The gaps

Ranked by what a user loses, worst first.

### G1 — Stop can leave a system-bus recording running forever

A recording the port cannot signal is never stopped and `stopped` is never
emitted, so the window spins on the please-hold page with Stop still showing,
Save never becomes sensitive, and the temporary log is never offered for saving.

- Upstream: `c-sources/pcap-monitor.c:756-775` (`cancellable_cancelled_cb`) does
  **two** things — `g_clear_pointer (&self->pcap_in, pcap_close)`, which closes the
  read end of dbus-monitor's stdout so the child dies of `EPIPE`, and
  `g_subprocess_force_exit`, with the comment "this has no effect on a privileged
  dbus-monitor". On top of that `:393-412` (`await_both_errors`) arms a
  **2-second** timeout that calls `handle_error` whether or not the child has
  exited, so `::stopped` is guaranteed.
- Port: `lib/bustle/monitor.rb:421-427` (`terminate`) sends only `SIGTERM` and
  rescues `Errno::EPERM`; `#stop` (`:176-180`) never closes `@pipe`. `#pump`
  (`:144-152`) returns `true` for ever because `read_available` (`:222-228`)
  answers `""` while the pipe is open but empty, so `finish` is never reached and
  `@stopped` stays false. There is no timeout anywhere.
- Exercised by: **nothing.** `drive_recording.rb` stops an *unprivileged*
  session-bus `dbus-monitor`, which `SIGTERM` does kill.

### G2 — `bustle-pcap` exits 1 where upstream exits 0

A script that checks `$?` to decide whether a capture is usable gets the opposite
answer from the port.

- Upstream: `c-sources/bustle-pcap.c:196-207` (`stopped_cb`) prints the error to
  stderr and calls `g_main_loop_quit`; `main` then falls through to `return 0`.
  Only a *failed construction* of the monitor exits 1 (`:222-231`).
- Port: `lib/bustle/pcap_cli.rb:280-286` (`report`) sets `@status = 1` for every
  non-cancellation, and `record` returns it.
- Observed: `ruby exe/bustle-pcap --address=unix:path=/nonexistent/socket
  /tmp/out.bustle` → `Error: g-io-error-quark 0 Failed to start dbus-monitor:
  Child process exited with code 1`, **exit 1**. Upstream prints its equivalent
  line and exits 0.

### G3 — the `stopped` signal's domain and code are not upstream's

Anything keyed on the pair — and the pair is the whole public contract of the
signal — sees a different error for the same failure.

- Upstream: `c-sources/pcap-monitor.c:359-368` steals the subprocess error, whose
  domain is `G_SPAWN_EXIT_ERROR` and whose code is the child's exit status, so a
  dbus-monitor that died reports `g-spawn-exit-error 1`.
- Port: `lib/bustle/monitor.rb:503-513` (`stop_with`), reached from `report_exit` (`:448-458`) reports every failure under
  `IO_ERROR_QUARK` with `IO_ERROR_FAILED` (0). Observed above:
  `g-io-error-quark 0`.
- The 126/127/0 mappings themselves (`monitor.rb:448-458`) are written and
  correct against `handle_error`, and are asserted by **no check anywhere** —
  see `.reports/accountability-ensurance.md`.

### G4 — Enter in the Record Address field does nothing

Type an address, press Return, nothing happens; upstream starts recording.

- Upstream: `data/RecordAddressDialog.ui:86` sets `activates_default=True` on
  `recordAddressEntry`, and `:108` makes `recordAddressRecord` the
  `response="-3"` action widget, so Return is the Record button.
- Port: `lib/bustle/record_address_dialog.rb:56` connects only `changed` on
  the `Adwaita::EntryRow` built at `:107-111`. Nothing connects `entry-activated` and the window has
  no default widget.
- Observed, driving the real dialog headless: after typing a valid address,
  `record sensitive after typing: true`, then
  `address_row.signal_emit("entry-activated")` → `recorded after Enter: nil`,
  `default widget set: nil`.

### G5 — Open-a-pair does not follow a browsed folder

Browse to the directory holding both logs in the first chooser and the second
chooser still opens in the home directory. Open since the first audit; the commit
that claimed to close "the widget parity gaps" did not touch it.

- Upstream: `Bustle/UI/OpenTwoDialog.hs:36-44` wires `current-folder-changed` on
  **both** choosers, with the guard that the other chooser has no file selected
  yet, so merely browsing moves the other one.
- Port: `lib/bustle/open_two_dialog.rb:140-145` (`propagate_folder`) only runs
  from `chosen`, i.e. once a file has actually been picked.
- `GtkFileDialog` has no signals, which is why this gap is expensive, not why it
  is closed. That belongs in `FINDINGS.md`; the neutral paragraph currently
  standing in `open_two_dialog.rb:21-25` is an accountability finding in its own
  right.

### G6 — the application never sets GLib's application name

Notifications, window-manager fallbacks and every GLib default that reads the
application name show the process name instead of the translated "Bustle".

- Upstream: `Bustle.hs:55` — `setApplicationName (__ "Bustle")`, before anything
  else happens.
- Port: `grep -rn 'application_name\|prgname' lib exe` returns nothing. One of the
  five upstream call sites of the `Bustle` msgid therefore has no counterpart;
  the msgid itself is still emitted from four others, so this is a component gap
  and not a translation gap.

### G7 — the welcome page is not greyscale

Upstream's own AppStream caption for this screen is "Relax with this soothing
greyscale welcome page". The port's is not greyscale, and its icon is less than
half the size.

- Upstream: `data/bustle.ui` dims **all three** children of `InstructionsPage` —
  the icon (`:474-481`, with `pixel_size=256`), the instructions (`:489-498`) and
  the title (`:508-518`, additionally `weight=bold scale=2`).
- Port: `lib/bustle/welcome_page.rb:31-38` puts `dim-label` on the description label
  only. The `Adwaita::StatusPage` icon and title take the platform defaults —
  undimmed, and the icon at the status page's own size.
- CSS axis totals: upstream attaches `dim-label` at 9 sites, the port at 2.

### G8 — the Arguments caption is emphasised where upstream dims it

- Upstream: `data/bustle.ui:716-726` — the `Arguments` caption carries
  `dim-label`, like the five captions beside it.
- Port: `lib/bustle/details_view.rb:79-84` gives it `heading`, which is GTK's
  bold/full-contrast class. (The other five captions become `Adwaita::ActionRow`
  titles under `.property`, which is the documented Adwaita equivalent of a dimmed
  caption — those five are a correspondence, not a gap.)

### G9 — `bustle`'s argument handling diverges in three places

- Upstream matches `args` against `["--help"]` **exactly** (`Bustle.hs:57`), so
  `bustle --count log --help` runs the count. Port: `main.rb:58` tests
  `@argv.include?("--help")`, so help wins wherever it appears.
- Upstream passes every argument that is not `--debug` to the loader
  (`Bustle.hs:50-52`, `UI.hs:160-166`), so `bustle --nonesuch` opens a window
  whose error bar reads `Could not read '--nonesuch'`. Port: `main.rb:113`
  rejects everything starting with `--`, so the typo is silently ignored.
- Upstream's `runOne` (`Bustle.hs:47-48`) demands the batch mode's argument list be
  exactly one element, so `bustle --count --debug log` is a usage error. Port:
  the same stripping makes it run.

### G10 — `bustle-pcap` announces before it knows it can record

- Upstream constructs the monitor first and, if construction fails, prints only
  the error and exits 1 (`c-sources/bustle-pcap.c:222-231`) — the two instruction
  lines at `:241-249` are never reached.
- Port: `lib/bustle/pcap_cli.rb:237-243` (`record`) calls `announce` before
  `recording.start`, so a port that cannot even spawn `dbus-monitor` still says
  "Logging D-Bus traffic to '…'…" and "Hit Control-C to stop logging." first.

### G11 — an unparseable frame warns on the wrong stream in the wrong words

- Upstream: `c-sources/bustle-pcap.c:176-186` — `g_warning ("%s", error->message)`,
  which goes to stderr in GLib's warning format.
- Port: `lib/bustle/pcap_cli.rb:269-275` returns `"Warning: #{e.message}"` into the
  same `--verbose` line stream on **stdout**, where it is indistinguishable from a
  captured message summary and corrupts the output of
  `bustle-pcap -v out.bustle | …`.

## What was checked and holds

Recorded so that the next audit does not redo it.

- **Accelerators.** All seven of upstream's (`bustle.ui:16, 26, 55, 77, 86, 95,
  335`) are bound, on the actions upstream's items carry them on, and no others:
  `menus.rb:24-40`. `open-pair`, `export-pdf` and `about` correctly have none, as
  upstream's `openTwo`, `headerExport` and `about` do. Driven:
  `drive_bustle.rb:176-188`.
- **Menus.** The three `Gio::Menu`s carry upstream's items in upstream's order and
  sections, with `statistics` as a stateful action standing in for upstream's
  `GtkCheckMenuItem` (`menus.rb:118-131`). Driven: `drive_bustle.rb:189-209`.
- **Sensitivity.** `statistics`, `filter` and `export-pdf` start disabled and are
  enabled by `display` (`window.rb:497`); `save` starts disabled and is enabled
  only by `recording_finished` (`window.rb:355`), matching
  `UI.hs:378-399`/`:664-684`. Driven: `drive_bustle.rb:197-209, 880-895`.
- **Canvas keys.** Up/Down/Home/End move the selection, Left/Right scroll one
  `eventHeight`, space scrolls a page, and a modified key is passed on
  (`canvas.rb:106-130` against `Canvas.hs:104-131`). The step increment is pinned
  on the adjustment's `changed` signal, which GTK4's viewport otherwise resets
  (`canvas.rb:138-141`). Driven: `drive_bustle.rb:256-380, 615-642`.
- **Error state.** Error-coloured box, both labels selectable, details hidden when
  absent, close button hides the bar — `error_bar.rb` against `bustle.ui:367-430`.
  Driven: `drive_bustle.rb:210-255`.
- **Details pane.** Five kind names from the same five msgids, the destination row
  hidden for a broadcast signal, a return borrowing its call's member, and every
  plain value escaped before it reaches a markup subtitle — `details_view.rb`
  against `DetailsView.hs:94-118`. Driven: `drive_bustle.rb:393-425`.
- **Statistics.** Three tables, upstream's column titles, the progress bar scaled
  against the busiest member with the `2 + count*98/upper` floor, the Frequency
  column a 120px **floor** rather than a fixed width, members ellipsized from the
  start at 30 characters, returns italic and errors red — `statistics_pane.rb`
  against `StatisticsPane.hs:130-226`. Driven: `drive_bustle.rb:426-478`.
- **Filter dialog.** `7/8 × 1/2` of the parent's size, 600×371 on the list and 600
  wide on the instructions, row banding standing in for `treeViewSetRulesHint`,
  namespace grouping to `org.example.{Foo,Bar}`, and closing the dialog applying
  the filter — `filter_dialog.rb` against `FilterDialog.hs:35-141`. Driven:
  `drive_bustle.rb:479-540`.
- **Recording flow.** 200ms batches, the counter moving only when the renderer
  produced shapes, the temporary file named after the local time with fractional
  seconds dropped, a productive recording re-read off that file, an unproductive
  one leaving the window as it found it, and the recovery advice on a failed save
  — `recorder.rb`/`window.rb` against `UI.hs:243-437`. Driven:
  `drive_bustle.rb:820-955`.
- **Name-owner seeding and the monitor's own name.** `monitor.rb:280-358` claims
  `org.freedesktop.Bustle.Monitor.<mangled unique name>` and issues one
  `GetNameOwner` per well-known name on a second connection, as
  `pcap-monitor.c:496-560` does on a thread. Verified **live**:
  `drive_recording.rb` reads the recorded log back and finds the monitor's own
  name in it.
- **`bustle-pcap` grammar.** `--long=value`, bundled short options, `--`, "Missing
  argument for -a", no abbreviations, a repeated bus flag counting once, a parse
  error outranking `--help`, and help text matching
  `g_option_context_get_help(context, FALSE, NULL)`. Driven:
  `drive_bustle.rb:1134-1209`.
- **Batch modes.** `--count`, `--time` and `--dot` produce upstream's formats
  (`" %4d %6s %s.%s"`, `" %9.4f %3d %9.4f %s.%s"`, the digraph) and a log that will
  not load is fatal. Driven: `drive_bustle.rb:1080-1133`.
- **Stylesheets.** Upstream ships no `.css` at all. The port's three heredocs
  (`error_bar.rb:28`, `statistics_pane.rb:52`, `filter_dialog.rb:33`) exist only
  to re-express GTK3 properties GTK4 dropped — `message_type=error`,
  `cellTextSizePoints := 7`, `treeViewSetRulesHint` — and each is installed once
  per display. libadwaita here is 1.9.3, so the `var(--error-bg-color)` syntax in
  `error_bar.rb` resolves.

## Correspondences, named and located

Not gaps; recorded so no later pass reports them as missing.

- `Gtk::ApplicationWindow` + `Adwaita::ToolbarView` for upstream's `GtkWindow` +
  `GtkHeaderBar`: `Adwaita::ApplicationWindow` is unusable in the Ruby bindings
  (`ruby-gtk` skill, `references/adwaita-quirks.md`). `window.rb:209-215`.
- `Gtk::Application` + ten `Gio::SimpleAction`s where upstream has no
  `GtkApplication` and hangs accelerators off `GtkMenuItem`s. This is upstream's
  own stated intent (`UI.hs:538-541`) rather than a divergence.
- `Gtk::DrawingArea` sized to the diagram inside a `Gtk::ScrolledWindow` for
  `GtkLayout`, which GTK4 removed; the draw function then works in diagram
  coordinates and the visible rectangle is computed from the adjustments
  (`canvas.rb:11-22, 196-206`).
- Whole-area redraw for upstream's two-stripe invalidation: GTK4 has no partial
  invalidation (`canvas.rb:23-24`, `Canvas.hs:134-170`).
- `Gtk::FileDialog` for `GtkFileChooserDialog`/`GtkFileChooserButton`
  (`open_dialog.rb`, `pdf_export.rb`, `recorder.rb:46-58`,
  `open_two_dialog.rb:160-168`).
- `Adwaita::AlertDialog` for `messageDialogNew` + `dialogAddButton`
  (`window.rb:414-430`), with the responses upstream adds in upstream's order.
- `Gtk::ColumnView` + `Gtk::SignalListItemFactory` for `GtkTreeView` +
  `ListStore` + cell renderers (`statistics_pane.rb`), and
  `Gtk::ListBox` + `Adwaita::ActionRow` + `Gtk::CheckButton` for the filter's
  toggle column (`filter_dialog.rb:205-217`).
- A `GLib::Object` wrapper around each statistics row, because `Gio::ListStore`
  cannot hold a Ruby `Data` (`statistics_pane.rb:30-46`).
- GTK3's `text-button` and `image-button` have no GTK4 counterpart; they were
  internal hints about a button's content, which `Adwaita::ButtonContent` and
  icon-only buttons now express structurally (`header_bar.rb:138-200`).
- `GLib.format_size` for upstream's `g_format_size` FFI shim
  (`missing.rb`), so size strings keep coming out of GLib's own catalogue.

## Re-audit at `732e6bb` (2026-11-06)

Re-run rather than re-read: `test/drive_all.rb` under `nix develop --command
xvfb-run -a ruby`, `rake spec` under the same display, and `rubocop` over
`lib exe test spec rakelib`. All three are clean (299/299, 24/0, 48 files/no
offenses), and `test/drive_all.rb`'s own coverage line lists all 22 component
numbers, so the gate is not narrow this round.

**G1, G2, G4, G6–G11 confirmed closed**, by reading the current code, not the
commit message that claims it:

- G1 (stop could hang forever): `lib/bustle/monitor.rb:94` defines
  `STOP_TIMEOUT_SECONDS = 2` and `#arm_stop_timeout` (`monitor.rb:479-490`)
  force-exits and calls `finish` after it, mirroring upstream's
  `await_both_errors`. Driven at `test/drive_bustle.rb` (polkit dismissed,
  refused, clean-exit and non-starting-child cases), against a fabricated
  exit status in every case — admitted as such in `PORTING.md`, not claimed as
  a real pkexec run.
- G2 (`bustle-pcap` exit code): `lib/bustle/pcap_cli.rb` now distinguishes
  "monitor would not start" (exit 1) from a runtime error (exit 0), matching
  upstream.
- G4 (Enter in Record Address): the entry now has a signal handler that
  activates the dialog's default response.
- G6 (application name): `Bustle._("Bustle")` is passed to
  `GLib.application_name=` (checked: `lib/bustle/application.rb`).
- G7/G8 (welcome page greyscale, Arguments caption): `welcome_page.rb` now
  builds the 256px greyscale image and dims the caption to match upstream's
  `.ui`; the drive screenshots it.
- G9 (`bustle` argument handling): `lib/bustle/main.rb` matches `["--help"]`
  as a whole and strips only `--debug` before handing the rest to the loader.
- G10/G11 (`bustle-pcap` announce timing, frame-warning stream/wording):
  `pcap_cli.rb` now waits for the subprocess to spawn before announcing, and
  an unparseable frame warns on stderr in upstream's words.

**G3 (the `stopped` signal's domain/code) is closed for the half it named**
— `report_exit` (`monitor.rb:521-531`) now carries `SPAWN_EXIT_ERROR_QUARK`
and the real exit status for a child that exited — **but driving it surfaced
a second, narrower divergence that G3's text did not cover**, carried forward
as new finding **G12** below, because closing the ticket and closing the
behaviour are not the same claim.

**G5 (Open-a-Pair folder travel) is still open.** `lib/bustle/open_two_dialog.rb:17-26`
still carries the same first-person admission: `Gtk::FileDialog` has no
`current-folder-changed` signal, so browsing (without picking) in one chooser
no longer moves the other. Confirmed unchanged against upstream
`OpenTwoDialog.hs:36-44`.

### G12 — the monitor does not prefer the libpcap error over the subprocess one (new this round)

Upstream's `await_both_errors`/`handle_error` (`c-sources/pcap-monitor.c:359-412`)
deliberately waits for both the pcap-parse error and the subprocess exit error
and then reports the pcap one, "including the wonderful snaplen bug" — pcap
errors are more specific. The port's `Monitor#finish` (`monitor.rb:498-504`)
has only one error path, `report_exit`, fed by the subprocess's wait status;
there is no second, pcap-side error source to arbitrate against, so whichever
happens to be read first (empirically the pcap-side read, since it runs
inline in `#drain`) wins by construction, not by the upstream rule. No test in
either drive script exercises the two racing, so this has not been seen to
misbehave — it is a structural gap, not an observed bug. Behaviour owed: when
a dbus-monitor subprocess dies with a generic error *and* the pcap stream it
was writing is independently malformed, the user should see the pcap
complaint, not whichever one the port's single-error-slot design happened to
read first.
