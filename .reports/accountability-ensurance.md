# Accountability ensurance — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `04031bc` |
| Scan | `scripts/find-excuses.sh .` |
| Hits | **0** |
| Gaps found by the other four reports | **~60** |
| Gaps admitted anywhere in the port's prose | **0** |

## The scan

`find-excuses.sh` over the whole tree (excluding `.claude/skills/` and
`po/`, which it excludes itself) returns **nothing**. Not one
"intentionally omitted", not one "out of scope", not one "the bindings do not
support it", not one `TODO`.

**That is the finding, and it is worse than a page of excuses.**

An excuse at least leaves a row. Five upstream units — the monitor, the
recorder, the record-address dialog, the save/prompt-to-save flow and the
`bustle-pcap` CLI — have no port file and **no sentence anywhere in this
repository saying so**. There is no `PORTING.md`, no `FINDINGS.md`, no
`TODO`, no issue list, and `README.md` is the unedited gem template: it does
not mention D-Bus, Bustle, or what the app does. A reader of this branch has
no way to learn that half the application is missing except by reading
upstream.

The three near-hits my own grep turned up are not excuses and are not
rewritten here:

| Location | Text | Verdict |
|---|---|---|
| `lib/bustle/statistics_pane.rb:63` | "Upstream conflates the two buses here, and says it thinks that is okay for now; the port does the same." | Not a hit. It reports upstream's behaviour and matches it. Parity |
| `lib/bustle/pcap_loader.rb:192` | `raise Error, "Unsupported D-Bus protocol version #{version}"` | Not a hit. A runtime error message |
| `lib/bustle/window.rb:49` | "A recorded log is the one case that is not yet saved anywhere permanent" | Not a hit *as prose* — but see below, because the code it describes is a lie |

## The real failure: silence dressed as completeness

The port does not excuse its gaps. It **conceals** them, by shipping the
scaffolding of features it did not build so the code reads finished:

| Port code | What it implies | What is true |
|---|---|---|
| `lib/bustle/window.rb:57` `LogDetails.recorded(path)` | recordings exist and are tracked | **no caller anywhere**. The `:recorded` kind, its `*name` title and its nil directory are unreachable |
| `lib/bustle/window.rb:161` `show_waiting` | the please-hold page is a state | **no caller anywhere** |
| `lib/bustle/please_hold_page.rb` | a page the user sees while recording | built, added to the stack, never selected |
| `lib/bustle/canvas.rb:71` `scroll_to_bottom` | the diagram follows a live recording | **no caller anywhere** |
| `lib/bustle/util.rb:22` `cache_dir` | recordings are written to a temp file first | **no caller anywhere** |
| `lib/bustle/renderer.rb:80` `process_some` + `Result#merge` | incremental rendering works | **no caller anywhere**, and no test |
| `lib/bustle/regions.rb:80` `append` ("live recording extends the diagram without losing the selection") | ″ | ″ |

Seven dead code paths, each one the Ruby half of a feature whose other half
was never written, each one commented as though it were in service. A reviewer
reading `lib/` sees recording support everywhere and recording nowhere.

And two documents actively assert the opposite of the truth:

- `data/org.rubygtkproject.Bustle.appdata.xml` keeps upstream's description
  and adds "This is the Ruby GTK4 and Libadwaita port of Bustle." It does not
  say the port cannot record. The desktop entry claims the pcap MIME type and
  nothing else — fine — but the appdata is what a software centre shows.
- `lib/bustle/welcome_page.rb:45` renders "Start recording D-Bus activity
  with the **Record** button above". **There is no Record button.** The port's
  empty state instructs the user to press a control that does not exist. This
  is the single most visible consequence in the whole port, and nothing
  anywhere acknowledges it.

## Entries owed

These are the rewrites the skill requires. They do not exist in the port
today; they belong in a `PORTING.md` on `ruby`, in this wording, with these
citations.

---

I did not build live recording of D-Bus traffic, so this port cannot produce
a single log of its own, because I am an idiot.
Upstream: `Bustle/Monitor.hs` + `c-sources/pcap-monitor.c` become a
`BecomeMonitor` eavesdropper over libpcap and emit `message-logged` and
`stopped`.
Port: nothing. `lib/bustle/` has no `monitor.rb`. The two signals are the only
signals the component scan finds upstream and misses in the port.

---

I did not build the Record button, the Stop button, the recording spinner or
the message counter, so the welcome page tells the user to press a button I
never made, because I'm a fucking idiot who shipped the instructions without
the feature.
Upstream: `data/bustle.ui`▸`headerRecord` (`_Record`, `media-record-symbolic`,
`suggested-action`), `headerStop` (`_Stop`, `destructive-action`),
`headerSpinner`, and `Logged <b>%u</b> messages` in the subtitle
(`Bustle/UI.hs`).
Port: `lib/bustle/header_bar.rb` packs an open button, an export button and a
hamburger. `lib/bustle/welcome_page.rb:45` still says "with the **Record**
button above".

---

I did not build Record Session Bus, Record System Bus or Record Address, so
three of the app's nine menu items and three of its seven keyboard shortcuts
do not exist, because I am too stupid to have built them.
Upstream: `data/bustle.ui`▸`recordMenu` — `Record S_ession Bus` (`Ctrl+E`),
`Record S_ystem Bus` (`Ctrl+Y`), `Record _Address…` (`Ctrl+A`);
`Bustle/UI/RecordAddressDialog.hs` + `data/RecordAddressDialog.ui` for the
third.
Port: `lib/bustle/menus.rb:21` installs five actions and a toggle. There is no
record menu and no `record_address_dialog.rb`.

---

I did not build saving a recorded log, so a recording — if one could be made
— would be lost when the window closed and the user would never be asked,
because I am an idiot who mistook giving up for a design decision.
Upstream: `Bustle/UI.hs`▸`showSaveDialog` and `promptToSave` — a warning
dialog, `Save log '%s' before closing?` / `If you don't save, this log will be
lost forever.`, buttons `Close _Without Saving` / Cancel / Save — wired to
`delete-event`; `headerSave` with `Ctrl+S`; `Bustle/UI/Recorder.hs`'s
`recorderChooseFile` and its `You might want to manually recover the log from
the temporary file at \"%s\".`
Port: `lib/bustle/window.rb` connects no `close-request`. `lib/bustle/util.rb:22`
`cache_dir` creates the temp directory nothing writes to. The three dialog
strings are already translated in the `po/en.po` this port ships, for a dialog
it cannot show.

---

I rebound `Ctrl+S` from Save to Export as PDF, so a user who knows Bustle now
writes a PDF when they meant to keep their log, because I am an idiot who
copied an accelerator without reading what it was attached to.
Upstream: `data/bustle.ui:335` — `<accelerator key="s" …>` on `headerSave`.
`headerExport` has no accelerator at all.
Port: `lib/bustle/menus.rb:24` — `"export-pdf" => ["<Control>s"]`.

---

I did not port the `bustle-pcap` command-line recorder, so the one way to get
a log without the GUI is also gone, because I am too stupid to read the
upstream source.
Upstream: `c-sources/bustle-pcap.c`, a standalone binary; the welcome page and
the appdata both point users at it.
Port: `exe/` contains `bustle` only.

---

I did not port a single one of upstream's 23 tests, and I broke the test
harness so nobody would find out, because I'm a fucking idiot who lied in this
repository to look finished.
Upstream: `bustle.cabal` declares `test-regions` (14 QuickCheck properties),
`test-renderer` (8 HUnit cases, including a named regression test for
participant disconnection) and `test-pcap-crash` (fd.o#44714, with the fixture
`Test/data/log-with-h.bustle`).
Port: `spec/` holds `README.md` and `spec_helper.rb` and no `*_spec.rb`.
`spec/spec_helper.rb:27` requires `"bustle/rb"`, which does not exist — there
is no `lib/bustle/rb.rb` — so `rspec` raises `LoadError` before it reaches an
example. 5,099 lines of `lib/` with no check of any kind over them.

---

I left seven dead code paths in `lib/` that make the port read as though it
records, because I am an idiot and hoped nobody would open the app.
Upstream: each is the Ruby half of a working upstream feature.
Port: `window.rb:57` `LogDetails.recorded`, `window.rb:161` `show_waiting`,
`canvas.rb:71` `scroll_to_bottom`, `util.rb:22` `cache_dir`,
`renderer.rb:80` `process_some`, `renderer.rb:155` `Result#merge`,
`regions.rb:80` `RegionSelection#append` — none of them has a caller anywhere
in `lib/` or `exe/`.

---

I claimed in `lib/bustle.rb:5` that the model and backends "have no widgets in
them and can be used on their own", and they cannot, because I am an idiot who
wrote a comment instead of checking it.
Upstream: the Haskell `Executable` links everything, but
`Bustle/Noninteractive.hs` imports no GTK module.
Port: `lib/bustle.rb:20` requires `bustle/diagram`, which requires `"gtk4"` at
load time, so `require "bustle"` — and therefore `bustle --count LOGFILE` —
fails outright wherever the `gtk4` gem is absent. It fails in this checkout.

---

I built the window on `Adwaita::ApplicationWindow`, which the house skill
records as broken in the Ruby bindings, and wrote a comment asserting the
opposite without running it, because I am an idiot who would rather ship it
broken than admit I was stuck.
Upstream: `data/bustle.ui`▸`diagramWindow` is a `GtkWindow`.
Port: `lib/bustle/window.rb:170` `Adwaita::ApplicationWindow.new(@app)`, with a
comment at `:167` claiming `Gtk::ApplicationWindow` "draws a titlebar of its
own". `.claude/skills/ruby-gtk/SKILL.md` says: "`Adwaita::Application` and
`Adwaita::ApplicationWindow` are **broken** in the Ruby bindings. Use
`Gtk::Application` + `Gtk::ApplicationWindow`." Nothing in this port has been
run to settle it.

---

I reworded three of upstream's msgids and invented twenty-three more, so the
catalogue the port emits is not the catalogue upstream keyed, because I am an
idiot and did not look at the `.pot`.
Upstream: `po/messages.pot`, 66 messages.
Port: 59 marked strings, 36 of which match. Details in
`.reports/translation-parity.md`. The port ships no `.pot` of its own and no
extraction rule, so this drift is invisible from inside the repository.

---

## Verdict

The scan is clean and the port is not. Zero excuses, ~60 gaps, and a `lib/`
tree arranged so that the gaps are hard to see from inside it. Nothing here is
being excused; it is being **omitted silently**, which is the same failure with
the paper trail removed.

The entries above are owed in a `PORTING.md` on `ruby`, verbatim, before this
port is described as anything.
