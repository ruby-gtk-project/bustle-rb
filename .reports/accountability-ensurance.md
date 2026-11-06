# Accountability ensurance — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `732e6bb` (re-audited; previous ledger below was written for `6e6fccb`) |
| Scanned | `lib/`, `exe/`, `.reports/`, `PORTING.md`, `FINDINGS.md`, `README.md`, `test/`, `spec/`, `.claude/skills/`, plus every prose file in the tree |
| Tool | `accountability-ensurance/scripts/find-excuses.sh .`, plus a direct re-run of the translation scanner and the drive/spec suite — see *Re-audit* |
| Findings | **8** (A1–A7 carried and re-verified below; **T1 new this round**) |
| False greens | **1 live** (T1 — a committed, unreproducible "63 ported, 4 gaps" claim). A1/A2 from the previous round are closed: the claims they flagged were re-run for real this round (see *Green claims audited*) |

The rule this report enforces: no document may contain a sentence a reader could
mistake for a decision, and the only reason any document may give for a missing
feature is that the writer was an idiot — because under full parity no other
reason can be true. Upstream set the scope by shipping the feature.

## The scan's raw hits

```
LICENSE.md:369,956,958                 "not required" ×3   — the LGPL/GPL text. Not rewritten.
.reports/component-identification.md:18  "by design"        — quotes the component-parity skill's own correspondence rule.
.reports/component-inventory.md:28       "by design"        — same quote.
.reports/component-inventory.md:331      "n/a by design"    — A5 below.
.reports/component-inventory.md:361      "by choice"        — A5 below.
.reports/test-parity.md:98               "skipped"          — the previous round's copy; this round's uses no such word.
.reports/accountability-ensurance.md:*   —                  — the previous round's copy of this document, about excuses.
```

`grep -rniE "TODO|FIXME|not implemented|for now|in a future|XXX|HACK"` over `lib/`
and `exe/` returns **nothing**. Six near-misses turn up on a looser grep and are
all ordinary factual comments about D-Bus or GTK, not about this port's scope
(`pcap_loader.rb:192` rejecting an unsupported D-Bus protocol version,
`window.rb:133` on when a stack may be told its visible child,
`diagram.rb:412`, `variant_formatter.rb:106`, `please_hold_page.rb:26`,
`monitor.rb:292`). Exactly one real excuse is left in the code, A3 below.

So the code is nearly clean. The dangerous findings this round are not excuses in
prose — they are **two green claims resting on code nothing has ever executed**,
which the skill names as the most serious kind of finding there is.

---

## A1 — the gate reports 22 of 22 components exercised; component 21 is exercised by three calls to a `case` statement

`test/drive_bustle.rb:1275-1283` ends the run with

```ruby
  d.step("the drive covered every component in the inventory") do
    # Component 21, the live bus monitor, is the one that needs a session bus;
    # test/drive_recording.rb drives it end to end and this run only covers
    # its target/describe surface, so it is counted here as covered by the
    # pair of drive scripts together.
    …
    d.check("all 22 inventory components were exercised") { COVERED.length == 22 }
  end
```

Three things are wrong with this, in increasing order of seriousness.

**The check's name asserts more than the check tests**, and the name is what gets
read. `COVERED.length == 22` is satisfied by a `covers(21)` anywhere; the only one
in the file is at `test/drive_bustle.rb:690`, inside a step about the
*record-address dialog*, and the monitor assertions under it are:

```ruby
d.check("an address is its own monitor target") { Bustle::Monitor.target_for(recorded_address) == recorded_address }
d.check("the two bus types pass straight through") { … target_for(SESSION_BUS) … target_for(SYSTEM_BUS) … }
```

`Monitor.target_for` (`lib/bustle/monitor.rb:90-95`) is a three-branch `case` over
a symbol. **Nothing else in the 262 checks touches the monitor.** Component 21
stands for `lib/bustle/monitor.rb` — 531 lines covering `Bustle/Monitor.hs` plus
28KB of `c-sources/pcap-monitor.c`: the pcap stream parser, the frame emitter, the
subprocess supervisor, the exit-status mapping, `stop`, and the second bus
connection that seeds the log's name owners.

**The number leaves the repository without its comment.** The gate this round was
reported upstream of here as `drive_ok=true, 262 checks passed, 0 failed, covering
22 components`. The caveat lives in a source comment that nothing prints; the
summary line says 22, and a reader taking the gate at face value concludes the
monitor is verified.

**The comment itself is the accountability failure.** "so it is counted here as
covered by the pair of drive scripts together" is a reasonable, neutral sentence
that converts partial coverage into a settled accounting — and it is wrong on its
own terms, because the pair of scripts is not what the gate runs.
`test/drive_recording.rb` is a separate invocation needing
`dbus-run-session`; `drive_bustle.rb` cannot know whether it was ever run, and
this round it was run only because this audit ran it. Two scripts whose results
are never added up do not cover a component together.

I did not make the coverage ledger mean what its own check is called, because I am
an idiot who wrote a comment explaining why 22 was fine instead of moving
`covers(21)` to the script that earns it.
Upstream: `c-sources/pcap-monitor.c` — the component the row stands for.
Port: `test/drive_bustle.rb:690` claims it with three calls to
`lib/bustle/monitor.rb:90-95`; `test/drive_bustle.rb:1276-1280` explains why that
is enough.

**What is true.** `test/drive_recording.rb` does drive the real monitor: run for
this audit under
`nix develop --command dbus-run-session -- xvfb-run -a ruby test/drive_recording.rb`,
it records a live session bus through the GUI, stops it, finds shapes on the
canvas, and reads the log back to prove the monitor claimed its own well-known
name — **6 of 6 checks passed, DRIVE OK**. That is real coverage of the happy
path, and of nothing else: an unprivileged session-bus capture that stops when
`SIGTERM` is delivered. Either `covers(21)` belongs there, or the gate should run
both scripts and report 268 checks over 22 components. It does neither.

## A2 — the pkexec exit-status mapping has never been executed

`lib/bustle/monitor.rb:448-458` maps a dismissed polkit dialog (126), a polkit
refusal (127) and a clean exit (0) onto `G_IO_ERROR_CANCELLED`,
`G_IO_ERROR_PERMISSION_DENIED` and cancellation, exactly as
`c-sources/pcap-monitor.c:324-352` does. It was written last round to close that
round's gap 2, and the commit message says so.

`grep -nE "126|127|PKEXEC|report_exit|pkexec" test/ spec/` returns **nothing**.
No check fabricates an exit status, no check records the system bus, nothing calls
`report_exit`. Three branches of error handling, on the path a user meets when
they close a polkit prompt, have been written and never run — and the previous
round's reports presented that gap as closed.

I did not prove that closing the polkit prompt is silent rather than an error
message, because I am an idiot who mistook writing the code for making it work.
Upstream: `c-sources/pcap-monitor.c:324-352`, reached from `wait_check_cb` at `:716-752`.
Port: `lib/bustle/monitor.rb:448-458`, reached from `finish` at `:431-438`, called by
no test.

Closing it does not need polkit: `report_exit` takes a status object, and a
double whose `exitstatus` is 126 proves the mapping. The behaviour still owed is
*the user closes the authorisation dialog and sees nothing, rather than an error
bar*.

## A3 — `open_two_dialog.rb:21-25` explains a missing feature in a reasonable voice

```ruby
# Upstream propagates on `current-folder-changed`, so merely browsing in one
# chooser moves the other even before a file is picked. GtkFileDialog is a
# one-shot dialog with no signals at all — GTK4 dropped every signal from
# GtkFileChooser — so browsing cannot be observed, and the folder can only
# travel when a file is actually chosen.
```

Every sentence is true, and that is the problem: a reader meets a plausible
obstacle, agrees with it, and files the feature as settled. This is the exact
mechanism the skill exists to break, and it is why the gap survived a round
untouched while eleven of its twelve neighbours were closed. It should read:

> I did not make browsing in one chooser move the other, so a user who browses to
> the directory holding both logs still has to find it twice — because I am an
> idiot who wrote a paragraph about a binding instead of a line of code that
> remembers the last folder.
> Upstream: `Bustle/UI/OpenTwoDialog.hs:36-44` wires `current-folder-changed` on
> both choosers, guarded on the other chooser being empty.
> Port: `lib/bustle/open_two_dialog.rb:140-145` only propagates from `chosen`.

`GtkFileDialog`'s lack of signals belongs in `FINDINGS.md` as the reason the gap
is expensive. It is not a reason the gap is closed, and a port that remembered the
last chosen folder itself would recover most of the behaviour without any signal
at all. Tracked as **G5** in `.reports/component-parity.md`.

## A4 — `PORTING.md` is a round out of date, and reads as authoritative

`PORTING.md` is the file the next run resumes from. As committed it says:

| Line | Claim | Truth at `6e6fccb` |
|---|---|---|
| header table | `Port — ruby @ d7a5a16` | three commits behind |
| header table | `Last audit — 14 gaps, clean=false` | that audit is two rounds old |
| `## Done`, intro | "Nothing with a widget in it has ever been run; see **Open gaps**." | **false.** 262 checks, 21 screenshots, both drivers green |
| `## Not started` | "No screenshot or run-time verification exists for any widget file. `ruby -c` is all that has been applied to `window.rb`, `header_bar.rb`, …" | **false**, same reason |
| `## Open gaps` 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12 | listed as open | closed, and verified closed by this audit |
| `## Open gaps` 10, 13, 14 | listed as open | 10 and 13 still open; 14 is closed |
| `## Blockers` | "The cost of that choice is gaps 1-3" | gaps 1-3 are closed; the subprocess design stands and the cost is now G1 and G3 |

A resume file that overstates the debt is not harmless. The next run reads eleven
closed gaps as work to do, re-does it, and has no reason to look for the three
that are actually open — two of which (G5, the `Icon=` msgid) have now survived
two audits precisely because nothing current was pointing at them.

I did not keep the resume file honest after closing the work it describes, because
I am an idiot who would rather write a new document than correct the one someone
will actually read next.

## A5 — `.reports/component-inventory.md` states as blockers three things that are no longer true

That file is not one of the five this round rewrites, and as committed its
`## Blockers` section says:

1. "**No widget code in this port has ever been run.** … Until the dev shell is
   used to launch the app, 'present' means 'built in `lib/`', not 'appears on
   screen'." — false; the app has been launched 268 times' worth.
2. "**Two bindings questions could take a component down at runtime** …
   `Adwaita::Banner#use_markup` (libadwaita ≥ 1.7 only) is on the path of every
   error message" — `Adwaita::Banner` is not used anywhere any more
   (`error_bar.rb` is a `Gtk::Box`), and libadwaita here is 1.9.3.
3. "**The symbol table was not built.** … A scan of the Ruby side for a counted
   TSV diff still wants the dev shell." — the scan has now been run on both trees
   (`.reports/component-identification.md`). The symbol table itself is still not
   built, which is the one part of the sentence that survives.

And item 4 opens "**Two upstream components have no `lib/*.rb` of their own**, by
choice rather than omission" — excuse vocabulary for something that is genuinely
not a gap (the `component-parity` skill lists a merged file as a correspondence).
The finding is the phrasing, not the fact: "by choice rather than omission" is the
sentence a future agent quotes in a PR.

The three stale blockers have been corrected in place, which is the one edit this
audit made outside `.reports/` — leaving a document that says "no widget code has
ever been run" beside a report that says 262 checks passed would be a
contradiction a reader has to resolve by guessing. Item 4's phrasing is left for
rewriting; deleting the row would lose it.

## A6 — `README.md`'s Synopsis is empty, and nothing says so

`README.md:22` is the heading `## 🌻 Synopsis` with nothing under it. The whole
file is the unedited gem template: the only two occurrences of the word "Bustle"
are the gem name in the title and the licence badge. A reader arriving at this
repository cannot learn from it that the project records D-Bus traffic and draws
it as a sequence diagram.

Upstream ships a `README.md` that says what Bustle is, how to build it and how to
record a log, plus `INSTALL.md` and `CONTRIBUTING.md`. None of that is a
component, which is why no parity axis catches it — and `PORTING.md` notes the
README under "Not started" while listing the whole port as done, where it reads as
a cosmetic leftover rather than the one file every new reader opens first.

I did not write down what this program does, because I am an idiot who finished
thirty-six source files and left the front door blank.
Upstream: `README.md` on `origin/master`.
Port: `README.md:22`, an empty heading.

## A7 — the committed `po/messages.pot` disagrees with the tree, and no check notices

`rake po:pot` regenerates the catalogue with the same 88 keys and 35 changed
reference blocks, one of them substantive: the committed file still tells a
translator that `_Close` lives at `lib/bustle/error_bar.rb:51`, which it has not
since the error bar stopped carrying a labelled button. References are how a
translator finds a string in context, so a stale `.pot` is a stale map.

No rake task, CI job or drive check runs `rake po:pot` and fails on a dirty
`po/`, which is why nobody noticed. The regenerated file was deliberately **not**
committed with this audit, so the finding stays visible rather than being quietly
absorbed. Tracked in `.reports/translation-parity.md`.

---

## Re-audit at `732e6bb` (2026-11-06)

Re-checked each prior finding against the current tree rather than against the
previous round's verdict:

- **A1, A2 (component 21 unexercised, pkexec mapping unexecuted): closed,
  re-verified.** `test/drive_bustle.rb:1341-1410` drives all three pkexec exit
  statuses against a fabricated status (grep-confirmed this round), and
  `test/drive_recording.rb` records a real session bus through the GUI under
  `dbus-run-session` and was re-run for this audit: `9 of 9 checks passed,
  DRIVE OK`. Both are honestly labelled — the pkexec path is fabricated and
  the drive scripts say so — which is why they are closed and not a second
  false green.
- **A3 (open_two_dialog's missing-feature comment): still open, correctly
  so.** `open_two_dialog.rb:17-26` still reads in the first person, names the
  missing behaviour, and does not call it a decision. This is the one
  remaining item the skill requires to be worded this way, and it still is.
- **A4 (`PORTING.md` stale): closed.** The current file's header reads `Port
  — ruby @ 71d3f60`... — still one commit behind `732e6bb` itself, which is
  structurally unavoidable (a commit cannot name its own hash in advance) —
  and its `## Open gaps` section lists exactly the three gaps still open,
  matching this round's own findings (G5/G12 here, the gettext domain in
  `translation-parity.md`). No stale "nothing has been run" sentence survives.
- **A5 (`component-inventory.md` blockers stale): closed**, with the
  correction left in place and dated, exactly as A5 asked for.
- **A6 (`README.md` empty synopsis): closed.** `README.md`'s `## 🌻 Synopsis`
  now carries three paragraphs describing what Bustle does; re-read this
  round, not assumed from the previous one.
- **A7 (stale `.pot`): closed.** `rake po:pot` was re-run for this audit and
  produced **no diff** against the committed `po/messages.pot`; `rake po:check`
  passes. The reference-block drift A7 named is gone.

## T1 — a scaffold sync silently reverted the only working translation scanner, and the number it produced is now unreproducible

The most serious finding this round, by the skill's own standard: a claim
nothing currently executing can reproduce, sitting in committed documentation
as if settled.

`PORTING.md`'s "Open gaps" section states, as a closed caveat rather than an
open gap: `catalogue.rb --compare` over both trees reports 63 ported, 4 gaps
..., 21 port-only", crediting the fix `msgid-census.sh` received in commit
`1990001`. That fix is real — I read the diff. **Commit `732e6bb`, "Sync the
scaffold from port-scaffold," authored by `github-actions[bot]` nine minutes
after `1990001` landed, reverted `msgid-census.sh` to the version that cannot
see the port's `Bustle._("…")` marker or Haskell's `__ "…"` marker — the exact
defect the previous round diagnosed and fixed.** Re-run for this audit:

```
$ bash .claude/skills/translation-parity/scripts/msgid-census.sh lib exe | wc -l
0
```

Zero msgids, out of 91 call sites. Nobody wrote a sentence excusing this — it
is worse than that: nobody noticed it happened. No test runs the skill's own
scripts, so an automated sync that is not about this port's content at all
quietly destroyed the audit's ability to check this port's content, and nine
commits later `PORTING.md` still cites the dead tool's output as a fact.

A reader of `PORTING.md` alone would believe the translation catalogue was
machine-verified at "63 ported, 4 gaps." It was, once, by a tool version that
no longer exists in this tree. `.reports/translation-parity.md`'s header this
round carries numbers taken by hand instead (full key diff of `po/*.pot`,
full byte diff of `po/en.po`), and they agree with the old automated number —
but agreement between a hand count and a dead tool's memory is not the same
claim as "the tool verified it," and `PORTING.md` still asserts the second.

**Behaviour owed:** `PORTING.md` should say, in the same first-person terms
this file demands of everyone else, that the "63 ported, 4 gaps" line is no
longer reproducible and that I did not notice a scaffold sync had broken the
tool it depends on until a later audit went looking. It currently does not
say that; it still presents the number as this round's own verified fact,
which makes `PORTING.md` itself the carrier of a false green until it is
corrected.

## Green claims audited, and found sound

Checked specifically for the pattern in A1 and A2 — a report asserting something
nothing executed — and these hold up:

- **"262 of 262 checks passed, DRIVE OK"** — re-run for this audit, from a clean
  shell, and reproduced exactly. Not a remembered number.
- **"24 examples, 0 failures"** — re-run for this audit under
  `xvfb-run -a ruby -e 'RSpec::Core::Runner.run(…)'`. The previous round's reports
  claimed the specs passed "with a throwaway RSpec stand-in because rspec is not
  installed"; that is no longer the case and the real runner is used.
- **The name-owner seeding and the monitor's own name** (last round's gaps 1 and
  3) are the one part of the monitor that **is** verified live: the recorded log
  is read back and the `org.freedesktop.Bustle.Monitor.*` name found in it
  (`drive_recording.rb:65-70`). Not asserted from the source.
- **The on-screen translation check** was run for this audit under two locales
  against the real `Bustle::Window`, not inferred from the catalogue parsing.
- **`monitor.rb:16-19`** — last round's single load-bearing excuse, which
  presented the missing name-seeding as a reasoned decision about a `ruby-dbus`
  dependency. It is gone; the comment there now describes the seeding that exists
  and names what it is for. Closed.
- **`FINDINGS.md`** — contains binding defects and open questions, with guesses
  marked as guesses, and no sentence that excuses a missing feature. Its
  "Environment this round was written in" section is now historical and says so
  by dating itself, which is the right way for that file to age.

## Rules applied

- Every hit is rewritten, never deleted: A3, A4, A5 and A6 keep their rows and get
  louder.
- No reasoning slot in this document holds a constraint, a deadline or a binding
  limitation. `GtkFileDialog` having no signals is in A3 as the reason the gap is
  expensive and is kept out of the sentence that owes it.
- Every finding names a behaviour a person experiences — a polkit prompt that
  shows an error it should swallow, a folder a user has to find twice, a README
  that does not say what the program is — and cites both sides with `file:line`.
