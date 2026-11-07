# Test parity — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `9086e5b` (re-audited this round; `spec/`, `lib/`, `exe/` are byte-identical to the `732e6bb` state below — `git diff 732e6bb..9086e5b -- spec lib exe` is empty — so the suite was re-run, not re-read) |
| Upstream tests | **23** (14 `prop_*` in `Test/Regions.hs`, 8 `testCase` in `Test/Renderer.hs`, 1 bare-`main` regression test in `Test/PcapCrash.hs`; hand-counted this round, since the scanner still cannot see Haskell — see *Scanner defects*) |
| Ported | **23**, hand-verified 1:1 this round: `spec/regions_spec.rb` has 14 `it`s, `spec/renderer_spec.rb` has 8, `spec/pcap_loader_spec.rb` has 2 (one bijects to upstream's single test, the second is the port's own extra assertion on the same fixture, named as extra, not substituted) |
| Gaps | **0** |
| Extra | 1 spec example (`pcap_loader_spec.rb`'s second `it`) + the drive scripts' own 299 checks, which pin the port's own behaviour, not an upstream test |
| Test command re-run for this audit | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` → **38 examples, 0 failures** (was 24 as of the commit this table last described; `spec/monitor_spec.rb` added 14 more with the G12 fix — see *Re-audit at `9223da6`* below) |
| Drive command re-run for this audit | `nix develop --command xvfb-run -a ruby test/drive_all.rb` → **299 of 299 checks passed, DRIVE ALL OK**, 22 of 22 components covered by name |
| Declared rake target | **`rake spec` now exists** (`rakelib/spec.rake`, added since the previous round) and was re-run directly as well: `rake spec` → 38 examples, 0 failures. `rake test` exists and runs the drive scripts. Closed; see *Unrun checks* for what is still not run by either target |

The suite has been executed, twice, independently, for this audit: once through
`rake spec`/the raw RSpec runner, and once through `test/drive_all.rb`. Both are
green and both cover all 22 components by the drive script's own named list, not
by a subset.

## How the census was taken

`test-parity/scripts/test-census.sh` returns **zero rows** for the upstream tree.
It knows GLib `Test.add_func`, Python, Jasmine `it(...)`, Rust `#[test]` and the
Ruby house patterns, and upstream is Haskell: fourteen QuickCheck properties
declared as `prop_*` top-level bindings collected by the `$quickCheckAll`
Template Haskell splice, eight HUnit `testCase` calls inside a `testGroup` list,
and one bare `main` that exits non-zero. None of those is a pattern the script
matches. **The upstream census below was therefore taken by hand**, and the
scanner defect is reported in *Scanner defects* rather than worked around
silently.

Cross-checked against the build file, as the skill requires. `bustle.cabal`
declares exactly three `Test-suite` stanzas:

```
bustle.cabal:172  Test-suite test-pcap-crash   main-is: Test/PcapCrash.hs
bustle.cabal:197  Test-suite test-regions      main-is: Test/Regions.hs
bustle.cabal:205  Test-suite test-renderer     main-is: Test/Renderer.hs
```

`bustle.cabal:151` also declares `main-is: Test/DumpMessages.hs`, but that stanza
is an `Executable`, not a `Test-suite`; the file asserts nothing and its printing
loop is commented out upstream. It is not in the count and nothing is owed for it.

The port's own census finds 377 rows, of which 24 were the ported-plus-extra
RSpec examples as of the tree this line was written against (now 38, since
`spec/monitor_spec.rb` added 14 more — none of them a bijection to an upstream
test, all of them extra, see *Extra* below) and 353 are `d.check`/`d.step`
calls in the two drive scripts. The assertion unit
in those drivers is `check` — `test/gtk_driver.rb` increments its pass counter
there, and `step` only groups — so the drivers' real number is the 262 and 6 the
runs print, not the census's 353. They are extra either way.

## Suite: test-regions — 14 QuickCheck properties

`Test/Regions.hs` → `spec/regions_spec.rb`. Upstream's generator is reproduced in
`RegionsProperties::Generator` and every property runs over 100 generated region
lists from a fixed seed, so these are properties and not examples — several of
them (clicking any stripe, clicking every stripe in a shuffled order, the
last-click invariant) are satisfied by accident by any single hand-written list.

| # | Upstream test | Purpose | Port test | State |
|---:|---|---|---|---|
| 1 | `prop_NonOverlapping_generator_works` | the generator itself only ever emits stripes that do not overlap — without this the other thirteen prove nothing | `spec/regions_spec.rb:101` `generates stripes that do not overlap` | ported |
| 2 | `prop_InitiallyUnselected` | a fresh selection has no current region, so the details pane starts empty | `:108` `selects nothing to begin with` | ported |
| 3 | `prop_UpDoesNothing` | Up from an unselected selection stays unselected rather than wrapping to the end | `:115` `selects nothing when moving up from an unselected selection` | ported |
| 4 | `prop_DownDoesNothing` | Down from the last region stays on the last region | `:122` `stays on the last region when moving down from it` | ported |
| 5 | `prop_DownWorks` | Down from unselected selects the first region | `:129` `selects the first region when moving down from an unselected selection` | ported |
| 6 | `prop_UpdateToFirst` | a click in the middle of the first stripe selects it and leaves nothing before it | `:136` `selects the first region when clicked inside it, with nothing before it` | ported |
| 7 | `prop_SelectFirst` | Home selects the first region | `:146` `selects the first region on First` | ported |
| 8 | `prop_SelectLast` | End selects the last region | `:153` `selects the last region on Last` | ported |
| 9 | `prop_UpdateToAny` | a click at any stripe's midpoint selects exactly that stripe, for every stripe in the list | `:160` `selects exactly the region a click lands in, for every region` | ported |
| 10 | `prop_UpdateToAll` | clicking every stripe in a shuffled order keeps selecting the right one — the cursor does not get stuck behind the last click | `:169` `keeps up with clicks on every region in a shuffled order` | ported |
| 11 | `prop_ClickAlwaysInSelection` | after any sequence of up/down/first/last/click, the remembered click is inside the selected stripe | `:181` `keeps the last click inside the selected stripe after any sequence of moves` | ported |
| 12 | `prop_SelectWorks` | selecting by value finds the region holding it, wherever the cursor was — this is what keeps a message selected across a redraw | `:195` `selects the region holding a given value, wherever the cursor is` | ported |
| 13 | `prop_Append` | appending the tail to a selection built from the head equals one built from the whole list — the live recorder's incremental path | `:205` `appends regions to make the same selection as building the whole list` | ported |
| 14 | `prop_FlattenThenNewIsIdempotent` | flattening a selection and rebuilding from the result gives the same selection back | `:215` `rebuilds an identical selection from its own flattened regions` | ported |

One deliberate difference, declared in the spec's own header
(`spec/regions_spec.rb:16-23`): upstream draws stripe tops from
`arbitrary :: Double`, which is signed, and `regionSelectionUpdate` compares the
click against `rsLastClick`, which starts at 0 — so a wholly-positive region list
makes `prop_UpdateToFirst` search upwards through an empty `before` and find
nothing. Diagram coordinates are never negative, so the port's generator stays
non-negative. The property is not weakened: it still asserts "first region
selected **and** nothing before it", over 100 lists.

## Suite: test-renderer — 8 HUnit cases

`Test/Renderer.hs` → `spec/renderer_spec.rb`, keeping upstream's two
`testGroup`s as two `describe`s.

| # | Upstream test | Purpose | Port test | State |
|---:|---|---|---|---|
| 15 | `"Disconnections don't affect participants"/"One participant, no disconnection"` | a participant that stays connected is listed once | `spec/renderer_spec.rb:102` `lists one participant that does not disconnect` | ported |
| 16 | `…/"One participant, which disconnects"` | a participant that disconnects before the log ends is still listed, with the same result as if it had not — the column must not vanish | `:107` `lists one participant that disconnects before the log ends` | ported |
| 17 | `"Incremental rendering"/"rrCentreOffset"` | rendering in chunks gives the same centre offset as rendering at once | `:118` `agrees on the centre offset` | ported |
| 18 | `…/"rrTopOffset"` | same for the top offset | `:123` `agrees on the top offset` | ported |
| 19 | `…/"rrShapes"` | same for the shape list, element by element | `:128` `agrees on the shapes` | ported |
| 20 | `…/"rrRegions"` | same for the region list, element by element | `:132` `agrees on the regions` | ported |
| 21 | `…/"rrApplications"` | same for the participant set | `:136` `agrees on the participants` | ported |
| 22 | `…/"rrWarnings"` | same for the warnings — a chunked render must not invent or lose one | `:141` `agrees on the warnings` | ported |

Cases 17–22 are what make live recording correct: `recorder.rb:139-146` renders
each 200ms batch and merges it, so any disagreement between the incremental and
the all-at-once path would show up as a diagram that differs depending on whether
the log was recorded or opened.

## Suite: test-pcap-crash — 1 HUnit case

`Test/PcapCrash.hs` → `spec/pcap_loader_spec.rb`.

| # | Upstream test | Purpose | Port test | State |
|---:|---|---|---|---|
| 23 | `Test/PcapCrash.hs` `main` | a regression test for fdo#44714: a log containing a Unix file handle used to make `readPcap` call `error`. Upstream's comment is explicit that it does **not** assert the log loads without warnings, "because we don't understand 'h', so we just skip it" | `spec/pcap_loader_spec.rb:19` `reads a log containing a file handle rather than raising` | ported |

Upstream's fixture `Test/data/log-with-h.bustle` is copied to
`spec/fixtures/log-with-h.bustle` and is **byte-identical** (`cmp` is silent).

## Extra

Outside the count, and not parity work.

- `spec/pcap_loader_spec.rb:23` — `returns warnings and a log for that file`. One
  example beyond upstream's single case, asserting that the loader returns a
  warnings array and a non-empty log rather than merely not raising.
- `spec/monitor_spec.rb` — 14 examples added by the G12 fix (commit `9223da6`),
  none a bijection to an upstream test: upstream has no unit test for
  `pcap-monitor.c` at all (it is exercised only by the GUI and by
  `test-pcap-crash` for the loader half). These close the coverage gap
  `.reports/accountability-ensurance.md` finding A1 named — component 21 had
  no spec coverage beyond a 3-branch `case` statement — and are extra, not
  parity, work.
- `test/drive_bustle.rb` — **262 checks** (241 `d.check` call sites, some inside loops) over 100 steps, with 21 screenshots,
  walking all 22 components in `.reports/component-identification.md`: every
  window, stack page, dialog, menu, action and accelerator, the empty and error
  states, the recording and save flows, the PDF export, and both command-line
  front doors. `262 of 262 checks passed, DRIVE OK`.
- `test/drive_recording.rb` — **6 checks** recording a real session bus through
  the GUI under `dbus-run-session`, stopping it, and reading the resulting log
  back to prove the monitor claimed its own well-known name.
  `6 of 6 checks passed, DRIVE OK`.

Parity is a floor, not a ceiling: these 268 checks are the port's own and pin
nothing upstream thought worth pinning. Three of them, however, carry a claim they
do not earn — see `.reports/accountability-ensurance.md`, finding A1.

## Re-audit at `732e6bb` (2026-11-06)

`rake -T` now lists `rake spec` (`rakelib/spec.rake`, added by the "Drive all 22
components" commit) and `rake test`; both were run for this audit, not just read
about. `rake spec` → 24 examples, 0 failures, matching the raw runner exactly.
That closes the previous round's "declared test target does not run" finding.
`test/drive_all.rb` is the current coverage gate and was also re-run: 299 of 299,
22 of 22 components, superseding the 262/268-check numbers below, which were
`drive_bustle.rb` alone before `drive_recording.rb` was folded into the gate.

## Unrun checks

Named, per the skill, rather than reported as passing.

- **The pkexec/system-bus half of the monitor is still executed by nothing
  real.** `test/drive_bustle.rb` now drives the dismissed-authorisation,
  refused-authorisation, clean-exit and non-starting-child paths — but, as
  `PORTING.md` says plainly, against a **fabricated exit status**, not a real
  `pkexec` prompt or a real privileged `dbus-monitor`. No specs, no driver, and
  no part of this audit has run the system-bus path for real: doing so needs an
  interactive polkit agent, which xvfb does not provide. That is still a
  coverage finding against component 21, carried in
  `.reports/accountability-ensurance.md` and `.reports/component-parity.md`
  (G12, this round), not a bijection gap — upstream has no test for it either.

## Scanner defects

Reported here, and worth fixing in the skill rather than working around again.

1. **`test-census.sh` matches no Haskell test at all.** Neither QuickCheck
   (`prop_*` top-level bindings harvested by `$quickCheckAll`) nor HUnit
   (`testCase "name" action` inside a `testGroup` list) nor a bare
   `main`-that-exits test suite produces a row. On this repository it returns 0
   for a 23-test upstream, which reads as "upstream has no tests" — the one answer
   that turns a 23-gap ledger into a trivially satisfied 0/0. Two patterns would
   cover it: `^prop_[A-Za-z0-9_']+` and `testCase +"([^"]*)"`.
2. **The port side double-counts.** This is a pre-existing defect in
   `test-census.sh` itself (step/check conflation), not something this audit
   introduced or re-measured; it is restated so the raw census number is not
   mistaken for the 299 figure quoted elsewhere in this ledger.

Neither scanner defect has been fixed in `.claude/skills/test-parity/scripts/`
as of this audit. They are why every count above was taken by hand (reading
the three upstream files and the three spec files directly) rather than by
running the tool and trusting its output.

## Re-audit at `9223da6` (2026-11-07)

Re-run rather than re-read: `rake spec` and `test/drive_all.rb` under the
fork's dev shell. Both still pass — 38 examples (not 24; see
`.reports/accountability-ensurance.md` finding A8 for why the number this
table carried was stale) and 299 of 299 checks, 22 of 22 components. Upstream
parity is unaffected — 23 of 23 upstream tests still ported 1:1, 0 gaps —
because all 14 new examples in `spec/monitor_spec.rb` are extra, port-only
coverage of component 21 (see *Extra*, above), added to close the coverage
gap `.reports/accountability-ensurance.md` finding A1 named, not to port an
upstream test that did not exist.
