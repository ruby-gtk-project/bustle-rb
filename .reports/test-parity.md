# Test parity — bustle-rb

| | |
|---|---|
| Upstream | `master` @ `0a8cf38` |
| Port | `ruby` @ `16f6787` |
| Upstream tests | 23 |
| Ported | 23 |
| Gaps | 0 |
| Extra | 1 |
| Test command | `bundle exec rspec` — **could not be run here** (see below) |

## How the census was taken

`scripts/test-census.sh` returned **0 rows** for the upstream tree. That is a
scanner miss, not a finding about upstream: the script knows GLib, pytest,
Jasmine, Rust and Ruby, and upstream is Haskell — QuickCheck `prop_*` functions
collected by a `$quickCheckAll` splice, and `test-framework`/HUnit `testCase`
calls. **This defect is owed back to the `test-parity` skill**; two more
patterns (`^prop_[A-Za-z_']+`, and `testCase "…"`) would have found all 23.

The build-file cross-check is what caught it. `bustle.cabal` declares three
`Test-suite` stanzas (`:170 test-pcap-crash`, `:195 test-regions`,
`:202 test-renderer`) and one `Executable dump-messages` (`:144`, buildable only
under the `InteractiveTests` flag). Three declared suites against zero census
rows meant the regexes had missed the registration form, so the suites below
were censused by hand, file by file.

`Test/DumpMessages.hs` is **not** a test: it is an `Executable`, it takes a
filename on `argv`, it asserts nothing, and its printing loop is commented out.
It is excluded from the count. `Test/data/log-with-h.bustle` is a fixture.

The port's census found 24 rows on `it(...)`, with no duplicate identifiers
(`cut -f2 | sort | uniq -d` is empty), so `file#identifier` is a sufficient key.

## Suite: test-regions — `Test/Regions.hs` (14 properties)

Fourteen QuickCheck properties over `Bustle.Regions`, each run by QuickCheck
over 100 generated `ValidRegions` — a sorted list of stripe tops, one stripe
per adjacent pair reaching a random fraction of the way to the next top, with
that fraction pinned at `1.0` one time in eight so stripes sometimes touch
exactly, and distinct values per stripe.

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `prop_NonOverlapping_generator_works` | the generator itself produces non-overlapping stripes — a guard on the other thirteen | `spec/regions_spec.rb#generates stripes that do not overlap` (:101) | ported |
| 2 | `prop_InitiallyUnselected` | a fresh selection has nothing selected | `spec/regions_spec.rb#selects nothing to begin with` (:108) | ported |
| 3 | `prop_UpDoesNothing` | Up from an unselected selection stays unselected — it does not wrap to the end | `spec/regions_spec.rb#selects nothing when moving up from an unselected selection` (:115) | ported |
| 4 | `prop_DownDoesNothing` | Down from the *last* region stays on the last region — it does not fall off | `spec/regions_spec.rb#stays on the last region when moving down from it` (:122) | ported |
| 5 | `prop_DownWorks` | Down from an unselected selection selects the *first* region | `spec/regions_spec.rb#selects the first region when moving down from an unselected selection` (:129) | ported |
| 6 | `prop_UpdateToFirst` | clicking the midpoint of the first region selects it **and** leaves `rsBefore` empty | `spec/regions_spec.rb#selects the first region when clicked inside it, with nothing before it` (:136) | ported |
| 7 | `prop_SelectFirst` | Home selects the first region | `spec/regions_spec.rb#selects the first region on First` (:146) | ported |
| 8 | `prop_SelectLast` | End selects the last region | `spec/regions_spec.rb#selects the last region on Last` (:153) | ported |
| 9 | `prop_UpdateToAny` | clicking the midpoint of *any* one region selects exactly that region, for every region in the list | `spec/regions_spec.rb#selects exactly the region a click lands in, for every region` (:160) | ported |
| 10 | `prop_UpdateToAll` | clicking every region in a **shuffled** order selects each in turn — the cursor is not left stranded by a backwards jump | `spec/regions_spec.rb#keeps up with clicks on every region in a shuffled order` (:169) | ported |
| 11 | `prop_ClickAlwaysInSelection` | after **any** sequence of up/down/first/last/click, the recorded last click lies inside the selected stripe | `spec/regions_spec.rb#keeps the last click inside the selected stripe after any sequence of moves` (:181) | ported |
| 12 | `prop_SelectWorks` | selecting by value finds the region holding it, wherever the cursor was | `spec/regions_spec.rb#selects the region holding a given value, wherever the cursor is` (:195) | ported |
| 13 | `prop_Append` | appending the tail to a selection built from the head equals building the whole list at once, split at every index | `spec/regions_spec.rb#appends regions to make the same selection as building the whole list` (:205) | ported |
| 14 | `prop_FlattenThenNewIsIdempotent` | flattening a selection and rebuilding from the result gives back an equal selection | `spec/regions_spec.rb#rebuilds an identical selection from its own flattened regions` (:215) | ported |

All fourteen are genuinely properties in the port, not examples: `each_case`
(`regions_spec.rb:88-92`) runs each one over 100 generated region lists from
`RegionsProperties::Generator`, which reproduces upstream's generator including
the one-in-eight dense case (`:76-82`).

**One narrowing, and it is a real one.** Upstream draws its stripe tops from
`arbitrary :: Double`, which is signed; the port's `tops`
(`regions_spec.rb:56-58`) draws from `random.rand(1000.0)`, which is not. The
spec's own header (`:16-24`) says why. The effect is that nine of these
fourteen properties no longer see a region list lying entirely below the
origin, so if `Regions#update` mishandles a negative stripe the port's suite
will not say so where upstream's would. Property 11 is unaffected — its clicks
still range over `-1000..1000` (`:80`). Carrying this row as `ported` is
correct (a named test pins the property) and the narrowing is mine to remove,
not to keep explaining.

## Suite: test-renderer — `Test/Renderer.hs` (8 cases)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 15 | `testGroup "Disconnections…"`▸`"One participant, no disconnection"` | a service seen in the log is listed as a participant | `spec/renderer_spec.rb#lists one participant that does not disconnect` (:102) | ported |
| 16 | …▸`"One participant, which disconnects"` | it is **still** listed when it disconnects before the log ends — a regression test for a bug the author says he almost introduced | `spec/renderer_spec.rb#lists one participant that disconnects before the log ends` (:107) | ported |
| 17 | `testGroup "Incremential rendering…"`▸`rrCentreOffset` | rendering one message at a time and merging gives the same centre offset as rendering the lot | `spec/renderer_spec.rb#agrees on the centre offset` (:118) | ported |
| 18 | …▸`rrTopOffset` | the same for the top offset — the log in this fixture has enough names to force a rejustification to the top, which is the case that breaks | `spec/renderer_spec.rb#agrees on the top offset` (:123) | ported |
| 19 | …▸`rrShapes` | the same for the shape list, compared element by element before length | `spec/renderer_spec.rb#agrees on the shapes` (:128) | ported |
| 20 | …▸`rrRegions` | the same for the clickable regions | `spec/renderer_spec.rb#agrees on the regions` (:132) | ported |
| 21 | …▸`rrApplications` | the same for the participant set | `spec/renderer_spec.rb#agrees on the participants` (:136) | ported |
| 22 | …▸`rrWarnings` | the same for the warnings | `spec/renderer_spec.rb#agrees on the warnings` (:141) | ported |

Cases 17–22 are the tests the live recorder depends on: `Recorder#render`
(`lib/bustle/recorder.rb:138-147`) merges one batch at a time onto the result so
far, which is only sound while incremental and all-at-once rendering agree.

## Suite: test-pcap-crash — `Test/PcapCrash.hs` (1 case)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 23 | `Test/PcapCrash.hs`▸`main` | fd.o#44714 — `Test/data/log-with-h.bustle` contains a Unix file handle (`h`), which used to make `readPcap` call `error`. It must load **without raising**; upstream's own comment says it deliberately does *not* assert "no warnings", because `h` is skipped | `spec/pcap_loader_spec.rb#reads a log containing a file handle rather than raising` (:19) | ported |

The fixture travelled with it: `spec/fixtures/log-with-h.bustle`.

## Extra

- `spec/pcap_loader_spec.rb#returns warnings and a log for that file` (:23) — one check on the shape of `read_pcap`'s return value. No upstream counterpart; outside the count.

## What is proven, and what is not

Of the four conditions this skill requires:

- counts equal — **yes**, 23 and 23;
- every ledger row has a named port test — **yes**;
- every named test exists by that name in the port tree — **yes**, verified against the port census;
- the suite passes under its own target — **not verified here, and claimed by
  the port.** `bundle exec rspec` reports `bundler: command not found: rspec`,
  `rspec` is not on `PATH` and `gem list rspec` is empty, so this audit never
  executed the suite. `FINDINGS.md:30-34` states that "all 23 ported specs pass
  against the real `lib/`", executed with "a throwaway RSpec stand-in, since
  `rspec` itself is not installed". That is a claim by the party being audited,
  made with a harness that is not in the repository and cannot be re-run, over
  a suite whose real runner has never been used on it. It is recorded, not
  accepted. Parity is 23/23 **on the census**; "23/23, green" is not a thing
  this report can say.

The same environment limit removes the one check that would have caught the
`component-parity.md` gaps cheapest: `spec/` contains no widget spec at all, so
the three `ruby-gtk-testing` drives that would exercise the canvas's step
increment, the error bar's styling and the filter list could not have been
written here either.

Upstream's suite is small for a 7,500-line app: the renderer, the region
selection and one pcap regression. Nothing upstream pins the UI, the monitor,
the statistics or the loader's name-ownership tracking — so the gaps in
`component-parity.md` (the monitor's missing `ListNames`/`GetNameOwner`, the
pkexec exit codes, the `bustle-pcap` option grammar) were never going to be
caught by a green suite, upstream's or this one.
