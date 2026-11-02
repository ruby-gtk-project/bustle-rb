# Test parity — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `04031bc` |
| Upstream tests | **23** |
| Ported | **0** |
| Gaps | **23** |
| Test command | `bundle exec rspec` — currently cannot run (see below) |

## Census

Upstream declares three `Test-suite` stanzas in `bustle.cabal`:

| Suite | `main-is` | Harness | Cases |
|---|---|---|---:|
| `test-regions` | `Test/Regions.hs` | QuickCheck `quickCheckAll` | 14 |
| `test-renderer` | `Test/Renderer.hs` | test-framework + HUnit | 8 |
| `test-pcap-crash` | `Test/PcapCrash.hs` | `exitcode-stdio-1.0` | 1 |

`Test/DumpMessages.hs` is an `Executable` behind the `InteractiveTests` flag,
not a test suite — it dumps a log to stdout for a human. It is outside the
count.

`Test/data/log-with-h.bustle` is the one fixture, and it **was not copied into
the port** — no `spec/fixtures`, no `spec/data`, nothing. Row 23 cannot be
ported until it is.

## The port's suite

`spec/` contains `README.md` and `spec_helper.rb`. **There are no `*_spec.rb`
files anywhere in the repository.**

Worse, the harness does not load: `spec/spec_helper.rb` line 27 is
`require "bustle/rb"`, and there is no `lib/bustle/rb.rb` — only
`lib/bustle/rb/version.rb`. Any `rspec` invocation raises `LoadError` before
it reaches an example. The suite is not empty-but-green; it is broken.

Independently, `require "bustle"` fails in this checkout because the `gtk4`
gem is not installed and `lib/bustle/diagram.rb` requires `"gtk4"` at load
time from `lib/bustle.rb`. So the backend modules the 23 upstream tests
actually exercise (`Regions`, `Renderer`, `PcapLoader`) cannot be required in
isolation either, despite `lib/bustle.rb`'s comment that the model half "can
be used on their own". Closing the gaps below needs that comment made true
first, or the specs will drag GTK4 into a headless test run.

## Suite: test-regions (14 tests) — `Test/Regions.hs` -> `Bustle::Regions`

The port's `lib/bustle/regions.rb` implements every function these properties
quantify over (`build`, `update`, `up`, `down`, `first`, `last`, `select`,
`append`, `flatten`, `last_click`, `non_overlapping?`), so there is no API
barrier to any row.

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `prop_NonOverlapping_generator_works` | the generator really does produce non-overlapping stripes | — | **gap** | `Regions.non_overlapping?` is true for any ascending stripe list built from sorted tops |
| 2 | `prop_InitiallyUnselected` | a fresh selection has nothing selected | — | **gap** | `RegionSelection.build(rs).current` is nil for any valid region list |
| 3 | `prop_UpDoesNothing` | Up from unselected selects nothing | — | **gap** | `build(rs).up.current` is nil |
| 4 | `prop_DownDoesNothing` | Down from the last region stays on the last region | — | **gap** | `build(rs).last.down.current` is the final region |
| 5 | `prop_DownWorks` | Down from unselected selects the first region | — | **gap** | `build(rs).down.current` is the first region |
| 6 | `prop_UpdateToFirst` | clicking inside the first stripe selects it and leaves nothing before it | — | **gap** | `update(midpoint_of_first)` selects region 1 and `before` is empty |
| 7 | `prop_SelectFirst` | `regionSelectionFirst` selects the first region | — | **gap** | `build(rs).first.current` is region 1 |
| 8 | `prop_SelectLast` | `regionSelectionLast` selects the last region | — | **gap** | `build(rs).last.current` is the final region |
| 9 | `prop_UpdateToAny` | clicking inside *any* stripe selects exactly that region | — | **gap** | for every region, `update(stripe.midpoint).current` is that region |
| 10 | `prop_UpdateToAll` | clicking every stripe in a shuffled order selects each one in turn | — | **gap** | repeated `update` across a shuffled region list never desynchronises the cursor |
| 11 | `prop_ClickAlwaysInSelection` | after any sequence of up/down/first/last/update, `rsLastClick` lies inside the selected stripe | — | **gap** | the invariant that makes `clamp_around_selection` safe; the port's `last_click` is never asserted anywhere |
| 12 | `prop_SelectWorks` | `regionSelectionSelect v` selects the region whose value is `v` | — | **gap** | `select(value)` finds a value held either before or after the cursor |
| 13 | `prop_Append` | appending the tail to a selection over the head equals a selection over the whole list | — | **gap** | `build(head).append(tail) == build(head + tail)`; this is what makes live recording extend a diagram without losing the selection |
| 14 | `prop_FlattenThenNewIsIdempotent` | `new (flatten rs) == rs` | — | **gap** | `RegionSelection.build(sel.flatten) == sel` |

These are *property* tests over generated inputs. Rows 1–14 each owe a Ruby
test that generates region lists rather than hard-coding one, or the property
is not being tested — a single hand-written example passes rows 9, 10 and 11
by accident.

## Suite: test-renderer (8 tests) — `Test/Renderer.hs` -> `Bustle::Renderer`

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 15 | `Disconnections…/One participant, no disconnection` | a service that sends a signal is listed as a participant | — | **gap** | `Renderer.process(log, []).applications.session_participants == [[:1.1, Set[]]]` |
| 16 | `Disconnections…/One participant, which disconnects` | a service that **disconnects before the log ends** is *still* listed as a participant | — | **gap** | the same assertion with a trailing `Disconnected` NOC event; upstream calls this "a regression test for a bug I almost introduced", and `lib/bustle/renderer.rb:690` ("a departed participant keeps its column for the record") is exactly the code it guards |
| 17 | `Incremental…/rrCentreOffset` | incremental `processSome` yields the same centre offset as one-shot `process` | — | **gap** | `process_some` fed one message at a time agrees with `process` on `centre_offset` |
| 18 | `Incremental…/rrTopOffset` | same for the top offset | — | **gap** | …on `top_offset`, over a log long enough to force rejustification (upstream uses 26 well-known names for exactly this) |
| 19 | `Incremental…/rrShapes` | same for the shape list | — | **gap** | …on `shapes`, compared as a list |
| 20 | `Incremental…/rrRegions` | same for the region list | — | **gap** | …on `regions`, compared as a list |
| 21 | `Incremental…/rrApplications` | same for the participant map | — | **gap** | …on `applications` |
| 22 | `Incremental…/rrWarnings` | same for the warnings | — | **gap** | …on `warnings` |

Rows 17–22 are the tests that make live recording possible at all: they pin
that `processSome` is equivalent to `process`. The port implements
`Renderer.process_some` and `Result#merge`/`shifted_shapes`/`shifted_regions`
(`lib/bustle/renderer.rb:80`, `:155`, `:168`) with nothing asserting any of
it, and no caller either — the recorder that would use it was not written.
Six untested, unused, non-trivial code paths.

## Suite: test-pcap-crash (1 test) — `Test/PcapCrash.hs` -> `Bustle::PcapLoader`

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 23 | `Test/PcapCrash.hs` | fd.o#44714 — a log containing a Unix file handle (`h`) must load without raising; upstream's loader used to call `error` | — | **gap** | `PcapLoader.read_pcap(fixture)` returns rather than raising, for a log with an `h`-typed argument. Needs `Test/data/log-with-h.bustle` copied into the port |

`lib/bustle/variant_formatter.rb` and `lib/bustle/pcap_loader.rb` both handle
signatures; nothing checks that `h` survives. Upstream's own comment on this
test notes it does not assert "no warnings", because `h` is skipped — so the
port's test must assert *loads without raising*, not *loads cleanly*.

## Extra

None. There is not one Ruby test in this repository, upstream-derived or
otherwise.

## Consequence

The port is ~5,100 lines of `lib/`, including a 747-line layout engine, a
536-line Cairo renderer, a 495-line pcap/D-Bus unmarshaller and a 220-line
region-selection structure, **with zero automated checks of any kind**.
Upstream wrote down 23 facts it considered worth pinning — including one
explicit regression test for a real bug — and the port has inherited none of
them. Parity is **0/23**.
