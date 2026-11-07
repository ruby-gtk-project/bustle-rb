# Translation parity — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `9086e5b` (re-audited this round; `lib/`, `exe/`, `data/`, `po/` are byte-identical to the `732e6bb` state the body below was written against — `git diff 732e6bb..9086e5b -- lib exe data po` is empty). **The header figures below (65 ported, 0 open gaps) are the hand count and still hold. `PORTING.md`'s separate claim that `catalogue.rb --compare` now confirms "57 ported, 10 gaps, 19 port-only" does NOT reproduce — see *Re-audit at `9086e5b`* at the end of this file, the most serious finding of this round** |
| Domain | **none** — the port reads `po/*.po` at runtime instead of binding a gettext domain. See *Delivery* |
| Upstream messages | **66** (distinct msgids in `po/messages.pot`, header excluded; hand-parsed this round — see *Re-audit*) |
| Ported | **65**, hand-verified by a full key diff this round |
| Gaps | **0 open** — the one remaining key difference (`org.freedesktop.Bustle`, upstream's `Icon=`) is settled this round as a deliberate non-port, not an open gap; see below |
| Extra (untranslated by definition) | **24** (89 port keys − 65 shared) |
| Upstream `po/en.po` | **36** msgid blocks including the header, i.e. **35** real translated strings; byte-identical to the port's `po/en.po`, confirmed by a full diff this round, zero difference |
| Languages shipped by the port | **1** (`en`), **all 35 translations byte-identical to upstream's** — reconfirmed by diff, not by re-reading last round's claim |
| Plurals | 0 upstream, 0 in the port |
| `msgctxt` | 0 upstream, 0 in the port |
| Build command | `nix develop --command rake po:pot` (extract); `rake data:merge` (merge into the desktop entry and the appdata) |
| **Scanner status this round** | **fixed again.** The qualified-receiver (`Bustle._("…")`) and Haskell `__ "…"` fix that commit `732e6bb` silently reverted has been reapplied verbatim; `bash .claude/skills/translation-parity/scripts/msgid-census.sh lib exe` now returns 93 rows for 91 real call sites, and `.claude/skills/translation-parity/scripts/census-smoke.sh` (new this round, wired into `rake po:check`) fails the build if it regresses again. See `PORTING.md` and `.reports/accountability-ensurance.md` T1 |

`en` is the whole catalogue: it translates Will Thompson's English into Will
Thompson's English (`'%s'` → `‘%s’`, `-` → `–`), which is small but is the only
donated work in the directory, and all 35 entries survive.

## How the census was taken

`msgid-census.sh` was run on both trees and **neither output is usable on its
own**:

- On upstream it reads the three `.ui` files, the two `.in` files and `po/`, and
  **nothing from the Haskell**: upstream's marker is `__ "…"` (a function from
  `Bustle.Translation`), which is in none of the script's eleven marker sets. 32
  of upstream's call sites are invisible to it.
- On the port it finds **8** keys outside `po/`, all of them in `data/`, and none
  of the 76 in `lib/` and `exe/`: the port's marker is `Bustle._("…")` /
  `_("…")`, and the script's `_` pattern does not match a receiver-qualified call.

So the two catalogues were taken as follows, and the discrepancy is stated rather
than reconciled away:

- **Upstream**: `po/messages.pot` (66 keys), cross-checked against a hand grep of
  `__ "…"` across `*.hs` (32 sites, 30 distinct keys, all present in the `.pot`)
  and against the `.ui`/`.in` rows the census did find.
- **Port**: a hand extraction of every `(Bustle.)?_("…")` literal in `lib/` and
  `exe/` (76 keys, 90 sites, string continuations folded) plus the `data/` rows
  from the census, cross-checked against the committed `po/messages.pot` (88
  keys).

Both scanner holes are reported under *Scanner defects*.

### The `.pot` cross-check, and what it found upstream

Upstream's `po/messages.pot` carries `POT-Creation-Date: 2018-11-15`, the same day
as upstream's last release, so it is a usable snapshot. Comparing it against a
source scan turns up a real upstream bug:

**Eight msgids marked `translatable="yes"` upstream have never been extracted, in
any language, ever.** Every string in `data/OpenTwoDialog.ui` and
`data/RecordAddressDialog.ui` is absent from `messages.pot` — upstream's
`Makefile` gettext rules read `data/bustle.ui` and the two `.in` files and not
those two:

`Address:`, `e.g. unix:abstract=/tmp/dbus-E5RlEB5Tzu,guid= b1c1921b62283b7b612b57305b20cc28`,
`Open a Pair of Logs`, `Record Address`, `Select session bus log`,
`Select system bus log`, `Session bus log:`, `System bus log:`.

The port emits all eight (`open_two_dialog.rb:71, 112, 114, 172, 173`,
`record_address_dialog.rb:63, 98, 109`) and lists them under **Extra**, because
they are keys upstream's catalogue does not have. That is the one place this port
can hand translators something upstream never did, and it is the right direction
for the difference to run. Worth reporting upstream.

## The gap — now a settled, permanent non-parity

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---:|---|---|---|---|---|---|---|
| 1 | — | `org.freedesktop.Bustle` | single | 1 → 0 | — | **decided: not ported** | — |

Upstream's `data/org.freedesktop.Bustle.desktop.in:5` is `Icon=org.freedesktop.Bustle`,
and `xgettext --language=Desktop` extracts the `Icon` key, so the icon name is a
msgid in upstream's catalogue (`po/messages.pot:247-249`, referencing
`desktop.in:6`, which is itself one line off from the `Icon=` line — `xgettext`'s
own desktop-file scanner mis-attributes the line number). The port's
`data/org.rubygtkproject.Bustle.desktop.in:5` is `Icon=org.rubygtkproject.Bustle`
and `rake po:pot` does not extract it, so the port's catalogue has no counterpart
key.

Two prior audits left this open pending either side changing. This round settles
it instead of re-litigating it a third time: **the port will not mark `Icon=` as
translatable.** `Icon=` names a file in an icon theme (`org.rubygtkproject.Bustle`
resolves to a `.svg`/`.png` on disk by that exact name); a translated value would
point at a file that exists in no theme, in no locale, breaking the icon lookup
for exactly the locales it was meant to serve. Nothing else in the GNOME/freedesktop
desktop-entry spec treats `Icon=` as translatable — only `Name=`, `GenericName=`,
`Comment=` and `Keywords=` carry that convention — so upstream's extracted key is
read as a packaging artefact of its own `xgettext --language=Desktop` invocation
(plausibly the same off-by-one visible in the `:6` reference above), not a
behaviour worth reproducing. The port's `rake po:pot`/`rake po:check` are
therefore correct as they stand, and this row is closed by decision rather than
by code: it will keep showing as upstream-only in a raw catalogue diff forever,
and that is the right outcome, not a gap.

## Ported — by upstream source file

All 65 remaining upstream keys are produced by the port, byte for byte. Grouped
by the upstream file the `.pot` lists first, with the port file opposite.

### `Bustle/StatisticsPane.hs` → `lib/bustle/statistics_pane.rb` (15 messages)

| msgid | Uses | Port site | State |
|---|---|---|---|
| `Member` | 2 → 3 | `statistics_pane.rb:154, 191` (+ `details_view.rb:77`) | ported |
| `Method` | 2 → 2 | `statistics_pane.rb:169, 315` | ported |
| `Signal` | 2 → 3 | `statistics_pane.rb:316, 325`, `details_view.rb:148` | ported |
| `Frequency` | 1 → 1 | `statistics_pane.rb:165` | ported |
| `Total` | 1 → 1 | `statistics_pane.rb:175` | ported |
| `%.1f ms` | 2 → 2 | `statistics_pane.rb:176, 186` | ported |
| `Calls` | 1 → 1 | `statistics_pane.rb:181` | ported |
| `Mean` | 2 → 2 | `statistics_pane.rb:185, 201` | ported |
| `Method call` | 1 → 2 | `statistics_pane.rb:322`, `details_view.rb:131` | ported |
| `Method return` | 1 → 2 | `statistics_pane.rb:323`, `details_view.rb:132` | ported |
| `Error` | 1 → 3 | `statistics_pane.rb:324`, `details_view.rb:133`, `pcap_loader.rb:75` | ported |
| `Smallest` | 1 → 1 | `statistics_pane.rb:197` | ported |
| `Largest` | 1 → 1 | `statistics_pane.rb:205` | ported |
| `Frequencies` / `Durations` / `Sizes` | 1 → 1 each | `statistics_pane.rb:86-88` | ported |

### `Bustle/UI.hs` → `lib/bustle/window.rb`, `header_bar.rb`, `recorder.rb` (8 messages)

| msgid | Uses | Port site | State |
|---|---|---|---|
| `Could not read '%s'` | 1 → 1 | `window.rb:179` | ported |
| `Logged <b>%u</b> messages` | 1 → 1 | `header_bar.rb:94` | ported |
| `Recording %s&#8230;` | 1 → 1 | `recorder.rb:92` | ported |
| `Couldn't save log: ` | 1 → 1 | `window.rb:389` | ported |
| `You might want to manually recover the log from the temporary file at "%s".` | 1 → 1 | `window.rb:394` | ported |
| `Save log '%s' before closing?` | 1 → 1 | `window.rb:411` | ported |
| `If you don't save, this log will be lost forever.` | 1 → 1 | `window.rb:417` | ported |
| `Close _Without Saving` | 1 → 1 | `window.rb:419` | ported |
| `Couldn't export log as PDF: ` | 1 → 1 | `pdf_export.rb:55` | ported |

### `data/bustle.ui` → `menus.rb`, `header_bar.rb`, `welcome_page.rb`, `please_hold_page.rb`, `details_view.rb` (24 messages)

`_Filter Visible Services…`, `_Statistics`, `O_pen a Pair of Logs…`,
`Record S_ession Bus`, `Record S_ystem Bus`, `Record _Address…` (`menus.rb:72-99`);
`_Record`, `_Stop`, `Record a new log`, `Open an existing log`, `Export as PDF`,
`Save` (`header_bar.rb:138-200`);
`Welcome to Bustle`, `Start recording D-Bus activity with the <b>Record</b> button above\n You can also run <i>dbus-monitor --pcap</i> from the command line`
(`welcome_page.rb:24, 45`);
`<big><b>Waiting for D-Bus traffic; please hold…</b></big>` (`please_hold_page.rb:43`);
`Type`, `Path`, `Member`, `Arguments`, `Sender`, `Destination`, `Directed signal`
(`details_view.rb:69-80, 146`);
`Display two logs—one for the session bus, one for the system bus—side by side.`
(`open_two_dialog.rb:107`). All **ported**.

The two-line welcome string is the one to watch: its msgid contains a real
newline, and the port reproduces it with an adjacent-literal continuation
(`welcome_page.rb:45-46`) so the key is byte-identical rather than two keys.

### `Bustle/UI/FilterDialog.hs` → `lib/bustle/filter_dialog.rb` (1 message)

`Unticking a service hides its column in the diagram, and all messages it is
involved in. …` — `filter_dialog.rb:226`, assembled from four adjacent literals so
the key matches upstream's Haskell string gap. **ported.**

### `Bustle/UI/AboutDialog.hs` → `lib/bustle/about_dialog.rb` (2 messages)

`Bustle` (`about_dialog.rb:49`), `Someone's favourite D-Bus profiler`
(`about_dialog.rb:51`). **ported.**

### `Bustle/Noninteractive.hs` → `lib/bustle/noninteractive.rb` (2 messages)

`Couldn't parse '%s': %s` (`noninteractive.rb:62`), `(no interface)`
(`noninteractive.rb:93`). **ported.**

### `Bustle/Util.hs` → `lib/bustle/util.rb` (1 message)

`Warning: ` (`util.rb:19`), trailing space included. **ported.**

### `data/*.in` → `data/org.rubygtkproject.Bustle.{desktop,appdata.xml}.in` (13 messages)

`Bustle`, `Draw sequence diagrams of D-Bus activity`,
`debug;profile;d-bus;dbus;sequence;monitor;`, the long AppStream description,
`Explore sequence diagrams of D-Bus activity`,
`See statistics summarizing the log`,
`Relax with this soothing greyscale welcome page`, and the six release-note
paragraphs from upstream's 0.7.x entries. All **ported** — the port's appdata
carries upstream's `<release>` history verbatim and adds its own 0.1.0 entry.

> Note: the release notes are in both `.pot` files but in **neither** census, on
> either side: the census excludes `<release>` descriptions per xgettext's ITS
> rules, while both `.pot` files were produced by extractors that include them.
> They were compared pot-to-pot.

## Uses mismatches — investigated, none open

Per the skill these are component questions, not translation rows. All three
upstream reuse cases resolve:

| msgid | Upstream | Port | Finding |
|---|---:|---:|---|
| `Bustle` | 3 (`AboutDialog.hs:46`, `bustle.ui:101`, `desktop.in`+`appdata`) **plus `Bustle.hs:55`** | 4 | **one call site missing**: `setApplicationName (__ "Bustle")` has no counterpart. The key is still in the catalogue, so this is `ported` here and a component gap there — `.reports/component-parity.md` **G6** |
| `_Record` | 2 (`bustle.ui:149`, `RecordAddressDialog.ui:39`) | 2 (`header_bar.rb:151`, `record_address_dialog.rb:89`) | accounted for |
| `Draw sequence diagrams of D-Bus activity` | 2 (`desktop.in`, `appdata`) | 2 | accounted for |

## Extra — 23 keys the port emits that upstream never had

Each one is English until somebody translates it, and nobody will: a fork is not
registered with l10n.gnome.org.

**Eight are upstream's own strings that upstream never extracted** (see the
`.pot` cross-check above) and are the good kind of extra: `Address:`, the
`e.g. unix:abstract=…` hint, `Open a Pair of Logs`, `Record Address`,
`Select session bus log`, `Select system bus log`, `Session bus log:`,
`System bus log:`.

**Nine replace GTK3 stock ids, which GTK4 deleted.** Upstream wrote `gtk-open`,
`gtk-cancel`, `gtk-close`, `gtk-about`, `gtk-save` and `gtk-new` and got GTK's own
translated labels for free; GTK4 has no stock items, so each had to become a real
msgid: `_Open`, `_Open…`, `_Cancel`, `_Close`, `_About Bustle`, `Choose…`,
`Main Menu`, `(none chosen)`, `Filter Visible Services`. These are the port's
to translate now, and nine labels in English is the price of GTK4.

**Four name things the port builds that upstream's `.ui` did not name**:
`Open a Log` (the open chooser's title, which upstream leaves `Nothing`),
`D-Bus logs` and `All files` (file filters, from the MIME type the desktop entry
already claims — upstream sets no filters at all), and `Empty or truncated file`
(`pcap_loader.rb`).

**Two are the port's own release note** in the AppStream file: the 0.1.0
description and `This is the Ruby GTK4 and Libadwaita port of Bustle.`

## Delivery

Checked, not assumed.

- **`domain_matches` cannot hold, and that is a real finding.** There is no
  gettext domain: `lib/bustle/translation.rb` parses `po/<lang>.po` at runtime
  (`:72-100`) and `Bustle._` looks the msgid up in that hash (`:118`). The skill
  accepts a runtime reader as *delivery* — the requirement is that the strings
  reach the user — while recording what it costs, and here the costs are:
  no `msgfmt -c` validation of the catalogue, no plural-forms engine
  (`tr(msgid)` takes one argument), no `msgctxt` support, and no `.mo` install
  rule for a distribution to hook. Upstream's catalogue has no plurals and no
  contexts, so nothing is broken **today**; the first upstream plural would be
  silently untranslatable. Open item, not waved through.
- **The catalogue reaches the screen.** Driven headless, the real
  `Bustle::Window` loading a missing log under two locales:
  - `LANG=LC_ALL=en_GB.UTF-8` → the error bar's title label is
    `<b>Could not read ‘/nonexistent/log.pcap’</b>` — the **translated** string,
    with `en_GB` falling back to the `en` catalogue as gettext would.
  - `LANG=LC_ALL=de_DE.UTF-8` → `<b>Could not read &apos;…&apos;</b>` — the
    untranslated msgid, which is the correct fallback for a language the port
    (and upstream) does not ship.
  This is the check the skill calls "the only one that is not a document", and it
  passes.
- **`Translation.init` is called from one place only** — `main.rb:46`. `exe/bustle`
  reaches it; `exe/bustle-pcap` does not, which matches upstream (`bustle-pcap.c`
  has no `setlocale`/`textdomain` call and none of its strings are marked).
- **`LINGUAS` matches the `.po` files** on both sides (`en`, one file).
- **No `POTFILES.in`** on either side: upstream's extraction is a `Makefile` rule
  naming three files, and the port's is `rakelib/translation.rake` globbing
  `lib/`, `exe/` and `data/`. A glob cannot fall through the hole upstream's
  hand-written list fell through, which is why the port picks up the eight
  strings upstream missed. There is nothing for a POTFILES completeness check to
  check.
- **`msgfmt` was not run** — it is not in the dev shell, and the port needs no
  `.mo`. Named as unrun.

## The committed `.pot` is stale

`rake po:pot` regenerates `po/messages.pot` with the **same 88 keys** — no msgid
has drifted — but with 35 changed `#:` reference blocks, and one of them is
substantive: the committed file still credits `lib/bustle/error_bar.rb:51` with
`_Close`, which that file has not said since the error bar stopped being an
`Adwaita::Banner` with a labelled button. The references in a committed `.pot`
are what a translator uses to find the string in context, and nothing in the
repository runs `rake po:pot` as a check, so they rot silently. The regenerated
file was **not** committed with this audit so the finding stays visible; closing
it is `rake po:pot` plus a CI step that fails on a dirty `po/`.

## Scanner defects

Both should be fixed in the skill, not worked around again here.

1. **`msgid-census.sh` cannot see the port's own marker.** The port writes
   `Bustle._("…")` from outside the module and `_("…")` from inside it. The
   script's `_` pattern requires the marker not to be preceded by an identifier
   character, which a `.` satisfies — but the receiver `Bustle` makes the whole
   token `Bustle._`, and the pattern does not allow a qualified receiver. Result:
   **0 of 76** keys in `lib/` and `exe/` are found, and the port reads as having
   no translatable strings at all, which would be the single most misleading
   output this skill can produce. Allowing an optional `[A-Z][A-Za-z0-9_]*\.`
   prefix fixes it.
2. **`msgid-census.sh` cannot see Haskell's marker.** Upstream's is `__ "…"`
   (`src-hgettext/Bustle/Translation.hs`), with a space before the string and no
   parentheses. 32 call sites are invisible, which on a Haskell GNOME app means
   the entire source side of the catalogue. Adding `__` to the marker list and
   allowing a space-separated argument covers it.
3. **Minor, in the skill's own tooling contract:** `catalogue.rb --compare` was
   not run, because with both censuses this wrong its output would be fiction.
   The numbers in this ledger's header therefore come from the hand census and
   the two `.pot` files; no YAML was generated, and none was hand-edited.

## Re-audit at `732e6bb` (2026-11-06): the scanner regressed between rounds

The previous round's `PORTING.md` entry for this audit records that
`msgid-census.sh` "saw neither side's marker until this round" and that fixing
it let `catalogue.rb --compare` run and report "63 ported, 4 gaps ... 21
port-only." That fix was real: commit `1990001` changed
`.claude/skills/translation-parity/scripts/msgid-census.sh` to allow a
qualified receiver (`Bustle._("…")`, which is how most of this port's call
sites are written) and to read Haskell's `__ "…"` marker.

**Commit `732e6bb`, "Sync the scaffold from port-scaffold," reverted that fix
file-for-file**, 29 lines removed with no replacement, as an automated
scaffold sync — not as a reviewed decision about this port. Re-run for this
audit:

```
$ bash .claude/skills/translation-parity/scripts/msgid-census.sh lib exe | wc -l
0
```

Zero. The scanner cannot see a single one of the port's 91 `Bustle._(...)`
call sites, for the exact reason the previous round diagnosed and fixed: the
qualified-receiver pattern was removed again. It also once again cannot read
`__ "…"` in any Haskell file, which matters for re-censusing upstream from
scratch rather than trusting the committed `.pot`.

**This means `PORTING.md`'s "63 ported, 4 gaps, 21 port-only" is no longer a
claim anyone can reproduce.** It was true when it was written, by a tool that
no longer exists in this form. Nothing in the repository flagged the
reversion — no test runs the skill's own scripts, so a scaffold sync silently
re-broke the audit tooling and the first sign of it is this round noticing
that the number in `PORTING.md` cannot be regenerated. That is the shape of
false-green the `accountability-ensurance` skill exists to catch, carried
forward there as finding T1.

**The port's actual translation parity was re-established by hand for this
round, not by trusting the stale automated number**: a full key diff of
`po/messages.pot` (upstream 66 keys, port 89 keys, exactly one upstream key —
the application ID string `org.freedesktop.Bustle`, renamed to
`org.rubygtkproject.Bustle` because the port is a different app ID — absent
from the port's set) and a full byte diff of `po/en.po` (identical, 35
translated strings, zero difference). The **1 gap** and **65 ported** figures
in the header above are this hand count, and they happen to match what the
now-unreproducible automated run claimed — which is reassuring but is not
itself proof; it means the hand count and the dead tool agree, not that the
tool works.

**Stale as of commit `ae190b4`:** the sentence above ("the scanner fix has not
been reapplied in this commit") was true when this section was written and is
false now — `ae190b4` reapplied the fix verbatim and added
`census-smoke.sh` to guard it. Left here, unedited, this paragraph would sit
one screen below a header that says "fixed again" and tell a reader the
opposite; that self-contradiction inside one file is itself a finding, carried
to `.reports/accountability-ensurance.md` as **T2** this round. The fix being
back in place does not, on its own, make `catalogue.rb --compare`'s *numbers*
trustworthy — see *Re-audit at `9086e5b`* below, which re-runs the now-fixed
scanner and finds its output still does not match what `PORTING.md` claims for
it.

## Re-audit at `9086e5b` (this round): the "fixed" scanner's number still does not reproduce

`census-smoke.sh` passes (93 rows for 91 real `Bustle._(...)` call sites,
re-run directly for this audit), so the qualified-receiver/Haskell-marker fix
itself is in place and working, confirming `ae190b4`'s claim about the fix.
**But `PORTING.md` makes a second, separate claim — that running
`catalogue.rb --compare` over `origin/master` and this branch "now" reports
"57 ported, 10 gaps, 19 port-only" — and that claim does not reproduce.**

Re-run for this audit, from a clean worktree of `origin/master` @ `0a8cf38`
against this tree's working copy (sha `9086e5b`), twice, deterministically:

```
$ ruby .claude/skills/translation-parity/scripts/catalogue.rb <upstream-worktree> --role upstream > up.yaml
$ ruby .claude/skills/translation-parity/scripts/catalogue.rb .                   --role port     > port.yaml
$ ruby .claude/skills/translation-parity/scripts/catalogue.rb --compare up.yaml port.yaml
summary:
  ported: 63
  gaps: 4
  extra: 21
```

**63 ported, 4 gaps, 21 extra — not 57/10/19.** This is not the stale,
scanner-blind number either (that one was 0, per T1): it is a third, different
number, produced by the scanner `PORTING.md` says is fixed, run against the
exact tree state `PORTING.md` says it was run against (`git diff
732e6bb..9086e5b -- lib exe data po` is empty, so nothing in the compared
trees could have moved between when `ae190b4` allegedly ran this and now).
Nobody committed the generated YAML to check against, so there is nothing to
diff the discrepancy against beyond re-running the tool, which is what this
section does.

Reading the 4 reported "gaps" by hand resolves them, and they are not real
content gaps:

| Upstream (reported "gap") | Port (reported "extra", same message) |
|---|---|
| `&lt;big&gt;&lt;b&gt;Waiting for D-Bus traffic; please hold…&lt;/b&gt;&lt;/big&gt;` | `<big><b>Waiting for D-Bus traffic; please hold…</b></big>` |
| `Start recording D-Bus activity with the &lt;b&gt;Record&lt;/b&gt; button above …` | `Start recording D-Bus activity with the <b>Record</b> button above\n You can a…` |
| `Unticking a service hides its column in the diagram,          \and all message…` | `Unticking a service hides its column in the diagram, and all messages it is inv…` |
| `You might want to manually recover the log from the temporary file at    …` | `You might want to manually recover the log from the temporary file at "%s".` |

Each "gap" and its paired "extra" are the same string: the left column is
upstream's raw GtkBuilder/Haskell literal with HTML entities (`&lt;`/`&gt;`)
left un-decoded and, for the multi-line ones, the source's literal
line-continuation whitespace (`          \`) left uncollapsed; the right
column is the port's normalized text. `catalogue.rb`/`msgid-census.sh` key
messages by exact string equality with no entity-decoding and no whitespace
normalization for multi-line builder/Haskell literals, so the same message
sorts into two different keys and shows up once as a "gap" and once as
"extra". **All four are false gaps** — the content is ported in every case —
and this is a defect in the skill's scripts, not in this port.

There is also a real parsing bug, distinct from the whitespace issue, that
produced one of the 21 "extra" rows:

```
id: ').first].compact.reject(&:empty?).uniq         end          def po_path(name)           File.join(PO_DIR, '
state: extra
port_sites: ['lib/bustle/translation.rb:58']
```

`msgid-census.sh` matched some marker-like substring inside
`lib/bustle/translation.rb`'s `candidates`/`po_path` methods (ordinary Ruby,
no `_(...)` call site) and extracted a multi-line chunk of source code as if
it were a translatable string literal. This is not a translation gap either —
it is the scanner inventing a 76th call site that does not exist, on top of
the real 76. Both defects (whitespace/entity non-normalization and this
false-positive extraction) belong in the skill's scripts.

**Conclusion:** the true automated gap count, once the four false "gaps" are
read as ported and the one garbage "extra" is discounted, is **0 real
gaps** — which agrees with this file's header, taken by hand. But that means
`PORTING.md`'s specific sentence — that `catalogue.rb --compare` itself "now
returns … 57 ported, 10 gaps, 19 port-only"" — is a number nobody can
currently reproduce, stated as settled fact immediately after fixing the exact
same kind of unreproducible-claim defect (T1) one paragraph earlier in the
same commit. That is the pattern the `accountability-ensurance` skill calls
the most serious finding there is, and it is carried there as **T2**.
