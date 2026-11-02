# Component parity — bustle-rb

| | |
|---|---|
| Upstream | `master` @ `0a8cf38` |
| Port | `ruby` @ `16f6787` |
| Units compared | 12 / 12 |
| Units with parity | 4 / 12 |
| Gaps | 12 |

Upstream is GTK3 and the port is GTK4/Libadwaita, so the widget axis cannot be
compared on type for nine upstream classes that GTK4 deleted. Each is recorded
as a located substitution in `component-identification.md` and the weight of
the comparison falls on the CSS, signal/action and text axes.

**Step 5 was not run.** Nothing below was driven: the port's `rspec` is not
installed in this environment (`bundler: command not found: rspec`), and no
unit was screenshotted. Every verdict here is from reading both sources. A
`parity` verdict in this ledger therefore means "the four axes agree in the
source", not "the behaviour was observed firing" — which is a weaker claim than
this skill asks for, and the difference is mine to close, not to describe.

---

## Unit: live recording / monitor — `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` -> `lib/bustle/monitor.rb`

| Behaviour | Upstream | Port | Verdict |
|---|---|---|---|
| spawn `dbus-monitor --pcap` | `pcap-monitor.c:797-798` | `monitor.rb:156` | parity |
| `pkexec` for the system bus | `pcap-monitor.c:794-795` | `monitor.rb:153-155` | parity |
| `flatpak-spawn --host` in a sandbox | `pcap-monitor.c:788-792` | `monitor.rb:150-152`, `/.flatpak-info` | parity |
| `--session` / `--system` / `--address ADDR` | `pcap-monitor.c:802-815` | `monitor.rb:161-167` | parity |
| frames copied verbatim to the log | `pcap_dump()` | `monitor.rb:193-195` | parity |
| `message-logged` / `stopped` signals | `Monitor.hs:112-137` | `monitor.rb:36-37,88` | parity |
| **seed well-known-name ownership** | `pcap-monitor.c:415-456` `list_all_names` — `ListNames`, then one `GetNameOwner` per well-known name, on a second connection, *"just used by the UI to fill in the initial owners of each well-known name"* (`:445-447`); dispatched from `dump_names_thread_func` (`:496-556`) | **nothing.** `monitor.rb` opens no D-Bus connection and makes no calls | **gap** |
| **own `org.freedesktop.Bustle.Monitor.<unique>`** | `pcap-monitor.c:31`, `:530` — so the viewer can hide the monitor's own connection | **nothing**; `monitor.rb:16-19` records the omission with a reason | **gap** |
| **pkexec dialog dismissed (exit 126)** | `pcap-monitor.c:326-332` → `G_IO_ERROR_CANCELLED`, "User dismissed polkit authorization dialog", which `UI.hs:326-331` then *swallows* | `monitor.rb:271-278` never reads the exit status; reports `IO_ERROR_FAILED` with raw stderr | **gap** |
| **not authorized (exit 127)** | `pcap-monitor.c:333-339` → `G_IO_ERROR_PERMISSION_DENIED`, "Not authorized to monitor system bus" | same — no mapping | **gap** |
| **clean exit (0) = bus shut down** | `pcap-monitor.c:343-352` → treated as cancellation, no error shown | reported as a failure | **gap** |
| libpcap errors preferred over subprocess errors | `pcap-monitor.c:355-372` | no precedence; whichever fires first | **gap** |

The first gap is the one that changes what a user sees. `lib/bustle/pcap_loader.rb:433-440`
already bustlifies a `GetNameOwner` reply into a name-ownership event — the
machinery is there and correct — but in a live recording nothing ever makes
those calls, so it is never fed. Consequence: every service that was already on
the bus when recording started is drawn as a bare unique name (`:1.42`) where
upstream draws `org.gnome.Shell`, and the filter dialog lists unique names
instead of service names. Opening a log recorded by upstream's `bustle-pcap`
shows the names correctly; recording with this port does not.

**Verdict: gap.** 6 of 13 rows open.

---

## Unit: canvas — `Bustle/UI/Canvas.hs` + `bustle.ui`▸`diagramLayout` -> `lib/bustle/canvas.rb`

| Widget / behaviour | Up × | Port × | Signals | Text | Verdict |
|---|---:|---:|---|:-:|---|
| drawing surface | 1 `Gtk.Layout` | 1 `Gtk::DrawingArea` + `ScrolledWindow` | ✓ `draw` | — | parity (substitution: GTK4 deleted `GtkLayout`) |
| left-click selects by y | 1 | 1 `Gtk::GestureClick` `button=1` | ✓ `pressed`, grabs focus | — | parity |
| Up / Down / Home / End move the selection | 1 | 1 | ✓ | — | parity |
| space = one page down | 1 | 1 | ✓ | — | parity |
| Left / Right = one step | 1 | 1 | ✓ | — | parity |
| **step increment = one event row** | `Canvas.hs:102-103` sets it on **both** adjustments to `eventHeight` (30.0) | **absent** — `canvas.rb:131` reads `adjustment.step_increment` and nothing ever sets it | — | **gap** |
| modifier guard | `[] <- eventModifier` | `state.to_i.zero?` | ✓ | — | parity |
| highlight stripe drawn under the shapes | 1 | 1 `Diagram::Highlight` | — | — | parity |
| clamp around the selection with half a row of padding | 1 | 1 `canvas.rb:177-181` | — | — | parity |
| scroll to bottom | 1 | 1 `canvas.rb:72` | — | — | parity |
| centre the timestamp column | 1 | 1 `canvas.rb:68` | — | — | parity |
| partial invalidation | 2 stripes | whole visible area | — | — | parity (GTK4 removed it; the redraw is a superset) |

The step-increment gap is small to write and visible to use: Left and Right are
meant to scroll by exactly one message row in a diagram whose rows are 30px,
and instead they scroll by GTK's default for the scrolled window. Both
adjustments are affected, so the scrollbar arrows are wrong too.

**Verdict: gap.** 1 of 12 rows open.

---

## Unit: error bar — `bustle.ui`▸`errorBar` -> `lib/bustle/error_bar.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| the bar | 1 `Gtk.InfoBar` | 1 `Adwaita::Banner` | ✗ `message_type=error` (`bustle.ui:369`) has no counterpart; the banner carries no `error` class | ✓ close→hide | — | **gap**: the error strip renders in the accent colour, not the error colour |
| title label | 1 | 1 (banner title) | ✗ `selectable="True"` (`bustle.ui:411`) dropped | — | ✓ | **gap** |
| details label | 1 | 1 | ✗ `selectable="True"` (`bustle.ui:427`) dropped | — | ✓ | **gap** |
| details hidden when absent | ✓ | ✓ `error_bar.rb:36` | — | — | — | parity |
| close button | built-in `show_close_button` | `button_label = _("_Close")` | — | ✓ | ✗ extra msgid | **gap**: `_Close` is a port-only msgid; upstream's close button is GTK's own, already translated everywhere |

Both labels are `selectable` upstream on purpose: the one thing a user does with
"Could not read '/path': …" is select it and paste it into a bug report. The
port's banner title cannot be selected at all and `error_bar.rb:57` never sets
`selectable` on the details label.

**Verdict: gap.** 4 of 5 rows open.

---

## Unit: `bustle-pcap` CLI — `c-sources/bustle-pcap.c` -> `lib/bustle/pcap_cli.rb`

| Behaviour | Upstream | Port | Verdict |
|---|---|---|---|
| `-e/--session`, `-y/--system`, `-a/--address`, `-v/--verbose`, `-q/--quiet`, `-V/--version`, `-h/--help` | `:43-67` | `pcap_cli.rb:56-66` | parity |
| exactly one FILENAME, else exit 2 | `:159-168` | `pcap_cli.rb:136` | parity |
| two buses → exit 2, upstream's wording | `:135-143` | `pcap_cli.rb:133` | parity |
| version notice, byte for byte | `:127-130` | `pcap_cli.rb:45-53` | parity |
| "Logging D-Bus traffic to '%s'..." / "Hit Control-C to stop logging." | `:255,260` | `pcap_cli.rb:188-189` | parity |
| `--verbose` per-message summary | `message_logged_cb` | `pcap_cli.rb:195-206` | parity |
| cancellation is not an error | `stopped_cb` | `pcap_cli.rb:211-216` | parity |
| **`--address=ADDRESS`** | `GOptionContext` (`:88-105`) accepts the `=` form | `pcap_cli.rb:105-123` matches exact tokens only; `--address=X` falls through `classify` to "Unknown option --address=X", exit 2 | **gap** |
| **bundled short options (`-vq`)** | GOption accepts | not matched → "Unknown option -vq" | **gap** |
| **abbreviated long options (`--sess`)** | GOption accepts | not matched | **gap** |
| **a repeated bus flag** | `!!session + !!system + !!address` (`:117`) — `-e -e` is **one** bus | `pcap_cli.rb:139` counts occurrences, so `-e -e out.pcap` exits 2 with "You may only specify one of…" | **gap** |
| **parse error outranks `--help`** | parse error checked first (`:108-116`, exit 2), `help` after (`:118`) | `pcap_cli.rb:127-131` returns no complaint when `@help` is set, so `--help --bogus` prints help and exits 0 | **gap** |
| `--help` text | generated by `g_option_context_get_help` | hand-written heredoc `pcap_cli.rb:25-43` | **gap**: approximates GLib's output rather than reproducing it; not byte-compared, and `-a, --address` carries no `ADDRESS` placeholder in either |

**Verdict: gap.** 6 of 13 rows open. The option grammar is the substance: a
script calling `bustle-pcap --address=unix:path out.pcap` works against
upstream and exits 2 here.

---

## Unit: filter dialog — `UI/FilterDialog.hs` -> `lib/bustle/filter_dialog.rb`

| Widget / behaviour | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| dialog sized parent·7/8 × parent/2 | 1 | 1 `filter_dialog.rb:35-36` | — | — | — | parity |
| Close applies the filter however the window closes | ✓ `dialogRun` then read the store | ✓ `close-request`→`apply`, `filter_dialog.rb:60-63` | — | ✓ | — | parity |
| instructions label | 1 | 1 | — | — | ✓ byte-identical | parity |
| one tick per participant | N | N | — | ✓ `toggled` via `CheckButton` | — | parity |
| `formatNames` brace compression `ns{A,B}` | 1 | 1 `filter_dialog.rb:120-155` | — | — | — | parity |
| returns the set of **unticked** names | ✓ | ✓ `filter_dialog.rb:173` | — | — | — | parity |
| re-renders through the whole renderer | `processWithFilters` | `window.rb:436` | — | — | — | parity |
| **row banding** | `treeViewSetRulesHint True` (`:72`), with the comment *"otherwise it's tough to see where each group starts and ends"* | `boxed-list` on a `ListBox` — separators, not banding | ✗ | — | — | **gap** |
| **name view size request 600×371** | `:74` | absent | — | — | — | **gap** |
| **instructions size request 600×−1** | `:121` | absent | — | — | — | **gap** |
| dialog title | none upstream | `_("Filter Visible Services")` | — | — | ✗ extra msgid | **gap** |

**Verdict: gap.** 4 of 12 rows open. A participant list is grouped output; the
banding upstream added on purpose is what makes the grouping readable, and a
`boxed-list` separator is not the same signal.

---

## Unit: open-a-pair dialog — `OpenTwoDialog.{hs,ui}` -> `lib/bustle/open_two_dialog.rb`

| Behaviour | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| title "Open a Pair of Logs" | 1 | 1 | ✓ | parity |
| two choosers, titled "Select session/system bus log" | 2 | 2 | ✓ | parity |
| "Session bus log:" / "System bus log:" | 2 | 2 | ✓ | parity |
| the two-logs explanation | tooltip on the menu item | group description | ✓ byte-identical | parity |
| Open insensitive until both chosen | ✓ | ✓ `open_two_dialog.rb:178` | — | parity |
| choosers cleared when the dialog hides | ✓ `hideMyself` | dialog rebuilt per activation | — | parity |
| **folder propagated between choosers** | `current-folder-changed` on **both**, so browsing in one moves the other (`:37-47`) | only when a **file** is chosen (`:133-139`); browsing propagates nothing | — | **gap** |
| Open / Cancel labels | `gtk-open` / `gtk-cancel` (GTK's own, translated everywhere) | `_("_Open")` / `_("_Cancel")` | ✗ 2 extra msgids | **gap** |
| "(none chosen)" / "Choose…" | no counterpart | 2 new strings | ✗ 2 extra msgids | **gap** (explained: `GtkFileChooserButton` showed the filename itself) |

**Verdict: gap.** 3 of 9 rows open.

---

## Unit: details pane — `UI/DetailsView.hs` + `bustle.ui`▸`detailsGrid` -> `lib/bustle/details_view.rb`

| Widget / behaviour | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| Type / Path / Member / Arguments / Sender / Destination captions | 6 | 6 | `dim-label` → row titles + `heading` | — | ✓ all 6 byte-identical | parity |
| the 5 kind names | 5 stack pages | 5 branches `details_view.rb:122-133` | — | — | ✓ | parity |
| sender, destination, path, member values | 4 labels | 4 row subtitles, `subtitle_selectable` | — | — | — | parity |
| member borrows the call's member for a return/error | ✓ | ✓ `details_view.rb:152-157` | — | — | — | parity |
| destination row hidden for a broadcast signal | ✓ | ✓ `details_view.rb:116-119` | — | — | — | parity |
| arguments, one per line with signatures | 1 `TextView` | 1 | — | — | — | parity |
| pane hidden when the selection clears | ✓ | ✓ `details_view.rb:48-54` | — | — | — | parity |
| **values escaped before a markup label** | `labelSetText` for sender/destination/path, `labelSetMarkup` only for member (`:104-114`) | `AdwActionRow#subtitle` interprets markup, and `details_view.rb:108-118` assigns raw strings | — | — | — | **gap** |

The escaping gap is narrow — D-Bus names and object paths cannot contain `<` or
`&` — but upstream drew the line between text and markup deliberately, on four
labels, and the port erased it on three of them.

**Verdict: gap.** 1 of 8 rows open.

---

## Unit: statistics sidebar — `StatisticsPane.hs` -> `lib/bustle/statistics_pane.rb`

| Widget / behaviour | Up × | Port × | CSS | Text | Verdict |
|---|---:|---:|---|:-:|---|
| 3 titled pages: Frequencies, Durations, Sizes | 3 | 3 | — | ✓ | parity |
| 3 scrolled windows, 3 views | 3+3 | 3+3 | `data-table` + `bustle-statistics` | — | parity |
| 10 columns with upstream's titles | 10 | 10 | — | ✓ Member/Frequency/Method/Total/Calls/Mean/Smallest/Largest all byte-identical | parity |
| `%.1f ms` | 1 | 1 | — | ✓ | parity |
| Method / Signal / Method call / Method return / Error kind labels | 6 | 6 | — | ✓ | parity |
| member ellipsised from the start, 30 chars, right-aligned | ✓ | ✓ `statistics_pane.rb:235-241` | — | — | parity |
| returns italic, errors red | ✓ `formatSizeInfoMember` | ✓ `statistics_pane.rb:304-311` | — | — | parity |
| frequency progress bar, `2 + count*98/max`, text = count | 1 | 1 `statistics_pane.rb:263-272,283` | — | — | parity |
| 7-point cell text | `cellTextSizePoints := 7` on all 10 renderers | one CSS rule on the three views, `statistics_pane.rb:37-41` | ✓ located | — | parity (correspondence: GTK4 column views have no such property) |
| both buses conflated | ✓ | ✓ | — | — | parity |
| **Frequency column width** | `treeViewColumnSetMinWidth 120` (`:148`) — a floor | `col.fixed_width = 120` (`statistics_pane.rb:145`) — a ceiling too | — | — | **gap**: the bar cannot grow when the sidebar is widened |

**Verdict: gap.** 1 of 11 rows open.

---

## Unit: main window — `Bustle/UI.hs` + `bustle.ui`▸`diagramWindow` -> `lib/bustle/window.rb` + `header_bar.rb`

| Widget / behaviour | Up × | Port × | CSS | Signals / actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| Record menu button | 1 | 1 | ✓ `suggested-action` (`text-button`/`image-button` supplied by `Adwaita::ButtonContent`) | ✓ `recordMenu` | ✓ `_Record` | parity |
| Stop button | 1 | 1 | ✓ `destructive-action` | ✓ clicked→`monitor.stop`, grabs focus | ✓ `_Stop` | parity |
| Open menu button | 1 | 1 | ✓ | ✓ `openMenu` | ✓ tooltip "Open an existing log" | parity |
| Save button | 1 | 1 | ✓ | ✓ `win.save`, `Ctrl+S`, insensitive until a recording exists | ✓ "Save" | parity |
| Export button | 1 | 1 | ✓ | ✓ `win.export-pdf`, no accel upstream either | ✓ "Export as PDF" | parity |
| main menu button | 1 | 1 | ✓ | ✓ | ✗ `Main Menu` is a port-only tooltip | **gap** (extra) |
| spinner | 1 | 1 | — | ✓ start/stop | — | parity |
| title / subtitle labels, markup | 2 | 2 | ✓ `title`, `subtitle` | ✓ `labelSetMarkup` | ✓ `Logged <b>%u</b> messages` | parity |
| 3-page stack | 1 | 1 | — | ✓ | — | parity |
| statistics sidebar starts hidden, F9 reveals | 1 | 1 | — | ✓ stateful `win.statistics` | ✓ `_Statistics` | parity |
| size group over sidebar header + stack | 1 | 1 | — | — | — | parity |
| one window per log; quit on the last | ✓ | ✓ `Gtk::Application` | — | — | — | parity |
| initial window re-used by Open/Record | ✓ `consumeInitialWindow` | ✓ `application.rb:53-68`, `window.rb:315` | — | — | — | parity |
| `promptToSave` on close | ✓ `delete-event` | ✓ `close-request`, `window.rb:398-406` | — | ✓ | ✓ all 4 strings byte-identical | parity |
| save a recording, `fileMove` | ✓ | ✓ `window.rb:379-387` | — | ✓ | ✓ incl. the recovery advice | parity |
| export PDF | ✓ | ✓ `pdf_export.rb` | — | ✓ | ✓ `Couldn't export log as PDF: ` | parity |
| recording title/subtitle, 200ms batching, count only when shapes appear | ✓ | ✓ `recorder.rb:30,142-150` | — | — | ✓ `Recording %s&#8230;` | parity |
| abandon a recording that produced nothing | ✓ | ✓ `window.rb:373-380` | — | — | — | parity |
| `--debug` draws shape bounds | ✓ | ✓ `main.rb:117`→`canvas.rb:189` | — | — | — | parity |

**Verdict: gap.** 1 of 20 rows open, and it is only an extra string.

---

## Units with parity

- **welcome page** — `bustle.ui`▸`InstructionsPage` -> `lib/bustle/welcome_page.rb`. 4 widgets, `dim-label` carried, both msgids byte-identical including the embedded `<b>`/`<i>` markup and the newline. `Adwaita::StatusPage` for upstream's hand-spaced box is a located substitution.
- **about dialog** — `UI/AboutDialog.hs` -> `lib/bustle/about_dialog.rb`. All 10 authors, the copyright line, the website, the licence read off disk with a warning rather than a crash, `modal`, `transient_for`, and `_("Someone's favourite D-Bus profiler")` byte-identical. Logo icon renamed with the app ID.
- **batch modes** — `Bustle/Noninteractive.hs` -> `lib/bustle/noninteractive.rb`. All three formats character for character (`" %4d %6s %s.%s"`, `" %9.4f %3d %9.4f %s.%s"`, the `digraph bustle` wrapper with `nub`-equivalent `uniq`), `_("Couldn't parse '%s': %s")` and `_("(no interface)")` byte-identical, exit status 1 on a load failure.
- **record-address dialog** — `RecordAddressDialog.{hs,ui}` -> `lib/bustle/record_address_dialog.rb`. Title, `Address:`, the placeholder with its translator comment, and Record insensitive while the entry is empty. The placeholder moving to the group description is a located substitution (`Adwaita::EntryRow` has no placeholder property) and it keeps upstream's bytes.
- **please-hold page** — one extra spinner, explained above; otherwise the single markup msgid is byte-identical.

---

## Text axis summary

73 of upstream's 74 message keys are produced by the port, byte for byte. The
one gap and the 15 port-only keys are in `translation-parity.md`; the 9 extras
that belong to a component are marked ✗ in the tables above.

## Stylesheet

Neither tree has a `.css` file; the port's one rule
(`statistics_pane.rb:37-41`) replaces a GTK3 cell-renderer property and has
nothing to diff against. Upstream's nine GtkBuilder element names
(`errorBarTitle`, `detailsPath`, `detailsMember`, `detailsArguments`,
`methodCall`, `methodReturn`, `error`, `signal`, `directedSignal`) are defined
by no stylesheet in either tree — dead upstream, correctly absent here.

Every CSS class the port attaches (`suggested-action`, `destructive-action`,
`dim-label`, `title`, `subtitle`, `heading`, `boxed-list`, `card`, `property`,
`data-table`) is a GTK or libadwaita platform class, so none needs a rule.

## Rows open, by cost to close

| # | Gap | Where |
|---|---|---|
| 1 | live recording never seeds well-known-name ownership | `monitor.rb` — needs `ListNames` + per-name `GetNameOwner` on a second connection |
| 2 | pkexec exit 126/127 and clean exit 0 not mapped to upstream's errors | `monitor.rb:271-278` |
| 3 | monitor owns no `org.freedesktop.Bustle.Monitor.*` name | `monitor.rb` |
| 4 | `bustle-pcap` rejects `--address=X`, `-vq`, `--sess` | `pcap_cli.rb:105-123` |
| 5 | `bustle-pcap` rejects a repeated bus flag; `--help` outranks a parse error | `pcap_cli.rb:127-139` |
| 6 | error bar is not error-coloured | `error_bar.rb:50` |
| 7 | error bar title and details are not selectable | `error_bar.rb:50,57` |
| 8 | canvas step increment is not one event row | `canvas.rb:131` |
| 9 | filter list has no row banding and no size requests | `filter_dialog.rb:96,114` |
| 10 | open-a-pair does not propagate a browsed folder | `open_two_dialog.rb:133-139` |
| 11 | statistics Frequency column is fixed-width, not min-width | `statistics_pane.rb:145` |
| 12 | details values go unescaped into markup subtitles | `details_view.rb:108-118` |
