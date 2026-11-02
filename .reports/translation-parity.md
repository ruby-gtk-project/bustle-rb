# Translation parity — bustle-rb

| | |
|---|---|
| Upstream | `master` @ `0a8cf38` |
| Port | `ruby` @ `16f6787` |
| Domain | `bustle` (upstream: `GetText_bustle`/`getMessageCatalogDomain`, `src-hgettext/Bustle/Translation.hs:12-20`; port: `lib/bustle/translation.rb:8`) |
| Upstream messages | 74 |
| Ported | 73 |
| Gaps | 1 |
| Extra (untranslated) | 15 |
| Upstream languages | 1 `.po` (`en`), 33 translated / 3 untranslated of 36 |
| Languages shipped by the port | 1 `.po` (`en`), 33 translated / 3 untranslated of 36 |
| Build command | `rake translation:*` (`rakelib/translation.rake`) |

## How the census was taken, and two scanner defects

`scripts/msgid-census.sh` could not be used as-is on either side, and both
failures matter because either one alone produces a report that looks clean.

**Defect 1 — the port's marker is invisible.** The port routes every string
through `Bustle._("…")` (`lib/bustle/translation.rb`), a module-function call.
The scanner's Ruby pattern wants a bare `_(`, so it matched **zero** rows in
`lib/` — all 143 port rows came from `po/`. Adding `Bustle._(`-style
qualified markers (`[A-Za-z_][A-Za-z0-9_]*\._\(`) would fix it. Until then,
running this skill on this port and comparing `cut -f1,2` over the whole census
silently compares the port's `.pot` against itself and reports parity.

**Defect 2 — Haskell is not read.** Upstream marks with `__ "…"`
(`Bustle/Translation.hs`), which the scanner does not know, so the upstream
census returned 45 keys — the three `.ui` files, the `.desktop.in` and the
AppStream metainfo — and none of the Haskell.

So the authoritative key sets here are:

- **upstream** = the source census (45) ∪ the committed `po/messages.pot` (66) = **74**
- **port** = the port's generated `po/messages.pot` (**88**), cross-checked by grepping each upstream key against `lib/` directly

Both defects are owed back to the `translation-parity` skill. Neither YAML
document was hand-edited; the counts above come from the union just described,
and this paragraph is the statement the skill requires when rows do not come
from the generated artifact.

**Upstream's `.pot` is stale and incomplete.** `POT-Creation-Date: 2018-11-15`,
and it is missing eight strings upstream's own source marks as translatable:

```
Address:                                              data/RecordAddressDialog.ui:73
Open a Pair of Logs                                   data/OpenTwoDialog.ui:7
Record Address                                        data/RecordAddressDialog.ui:7
Select session bus log                                data/OpenTwoDialog.ui:110
Select system bus log                                 data/OpenTwoDialog.ui:75
Session bus log:                                      data/OpenTwoDialog.ui:103
System bus log:                                       data/OpenTwoDialog.ui:91
e.g. unix:abstract=/tmp/dbus-E5RlEB5Tzu,guid= …       data/RecordAddressDialog.ui:88
```

Every one is in `data/OpenTwoDialog.ui` or `data/RecordAddressDialog.ui`, so
neither file is reaching upstream's extraction — `xgettext` has never read
them and no translator has ever been offered those eight strings. This is the
third of the skill's three cases: *only in the source, present in no po at
all.* It is **an upstream bug, today**, and it should be reported there.

The port carries all eight anyway, in its own `.pot`, so it offers
translations upstream cannot. That is the right direction for the difference
to run.

## Languages

```
$ diff <(ls up/po/*.po | xargs -n1 basename -s .po) <(cat up/po/LINGUAS)   # clean
$ diff <(ls po/*.po    | xargs -n1 basename)        <(ls up/po/*.po | xargs -n1 basename)
```

Both sides ship exactly `en.po`, both `LINGUAS` files say `en`, and both
catalogues reconcile identically: 36 `msgid` lines, 3 empty `msgstr`, so 33
translated, 0 fuzzy. Nothing was destroyed — but there was very little to
destroy. Upstream Bustle has one language, so this port inherits almost none
of the donated-translation asset that makes this check expensive elsewhere,
and the `.po` cross-check that would normally validate the census against what
translators were handed can only validate 36 of 74 keys here.

## Gap

| # | msgctxt | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|---|
| 1 | — | `org.freedesktop.Bustle` | single | 1 → 0 | — | **gap** |

`text_owed: org.freedesktop.Bustle`

Upstream marks the `Icon=` value of its desktop entry as translatable —
`data/org.freedesktop.Bustle.desktop.in:6`, extracted at
`po/messages.pot:248`. The port's entry is
`data/org.rubygtkproject.Bustle.desktop.in` and its `Icon=` line is not
marked, so the key is not produced.

Copying upstream's bytes would be wrong — the string is an icon name, and
`org.freedesktop.Bustle` is an icon this port does not ship. The row stays a
gap because the port produces no counterpart key at all; closing it means
either marking the port's own icon name the way upstream marks its own, or
getting upstream's row deleted as the extraction bug it almost certainly is. It
is not closed by deciding it does not apply.

## Ported — grouped by upstream source

### `data/bustle.ui` → `lib/bustle/{header_bar,welcome_page,please_hold_page,error_bar,details_view,statistics_pane,menus}.rb` (30 messages)

| # | msgid | Kind | Uses | Port site | State |
|---|---|---|---|---|---|
| 2 | `Bustle` | single | 1 → 2 | `window.rb:207`, `about_dialog.rb:49` | ported |
| 3 | `_Record` | single | 1 → 1 | `header_bar.rb:156` | ported |
| 4 | `_Stop` | single | 1 → 1 | `header_bar.rb:161` | ported |
| 5 | `Record a new log` | single | 1 → 1 | `header_bar.rb:145` | ported |
| 6 | `Open an existing log` | single | 1 → 1 | `header_bar.rb:170` | ported |
| 7 | `Save` | single | 1 → 2 | `header_bar.rb:178`, `window.rb:402` | ported |
| 8 | `Export as PDF` | single | 1 → 1 | `header_bar.rb:192` | ported |
| 9 | `Welcome to Bustle` | single | 1 → 1 | `welcome_page.rb:23` | ported |
| 10 | `Start recording D-Bus activity with the <b>Record</b> button above\n You can also run <i>dbus-monitor --pcap</i> from the command line` | single | 1 → 1 | `welcome_page.rb:45-46` | ported |
| 11 | `<big><b>Waiting for D-Bus traffic; please hold…</b></big>` | single | 1 → 1 | `please_hold_page.rb:43` | ported |
| 12 | `Frequencies` | single | 1 → 1 | `statistics_pane.rb:70` | ported |
| 13 | `Durations` | single | 1 → 1 | `statistics_pane.rb:71` | ported |
| 14 | `Sizes` | single | 1 → 1 | `statistics_pane.rb:72` | ported |
| 15 | `Type` | single | 1 → 1 | `details_view.rb:69` | ported |
| 16 | `Path` | single | 1 → 1 | `details_view.rb:75` | ported |
| 17 | `Member` | single | 1 → 3 | `details_view.rb:77`, `statistics_pane.rb:137`, `:168` | ported |
| 18 | `Arguments` | single | 1 → 1 | `details_view.rb:79` | ported |
| 19 | `Sender` | single | 1 → 1 | `details_view.rb:71` | ported |
| 20 | `Destination` | single | 1 → 1 | `details_view.rb:73` | ported |
| 21 | `Method call` | single | 1 → 2 | `details_view.rb:123`, `statistics_pane.rb:296` | ported |
| 22 | `Method return` | single | 1 → 2 | `details_view.rb:124`, `statistics_pane.rb:297` | ported |
| 23 | `Error` | single | 1 → 2 | `details_view.rb:125`, `statistics_pane.rb:298` | ported |
| 24 | `Signal` | single | 1 → 3 | `details_view.rb:143`, `statistics_pane.rb:291`, `:299` | ported |
| 25 | `Directed signal` | single | 1 → 1 | `details_view.rb:141` | ported |
| 26 | `_Filter Visible Services…` | single | 1 → 1 | `menus.rb:97` | ported |
| 27 | `_Statistics` | single | 1 → 1 | `menus.rb:98` | ported |
| 28 | `Record S_ession Bus` | single | 1 → 1 | `menus.rb:76` | ported |
| 29 | `Record S_ystem Bus` | single | 1 → 1 | `menus.rb:77` | ported |
| 30 | `Record _Address…` | single | 1 → 1 | `menus.rb:78` | ported |
| 31 | `O_pen a Pair of Logs…` | single | 1 → 1 | `menus.rb:86` | ported |
| 32 | `Display two logs—one for the session bus, one for the system bus—side by side.` | single | 1 → 1 | `open_two_dialog.rb:99-100` | ported |

Row 10 carries the one real risk on this axis and it survived: the msgid holds
its own `<b>`/`<i>` markup **and** an embedded `\n`, split across two Ruby
string literals (`welcome_page.rb:45-46`). The concatenation reproduces
upstream's bytes exactly, newline included. Row 11 likewise keeps
`<big><b>…</b></big>` inside the key rather than wrapping a shorter string in
markup — which is why `please_hold_page.rb` uses a markup `Gtk::Label` instead
of an `AdwStatusPage` title.

### `data/OpenTwoDialog.ui` → `lib/bustle/open_two_dialog.rb` (5 messages)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 33 | `Open a Pair of Logs` | 1 → 1 | `open_two_dialog.rb:63` | ported |
| 34 | `Session bus log:` | 1 → 1 | `open_two_dialog.rb:105` | ported |
| 35 | `System bus log:` | 1 → 1 | `open_two_dialog.rb:107` | ported |
| 36 | `Select session bus log` | 1 → 1 | `open_two_dialog.rb:171` | ported |
| 37 | `Select system bus log` | 1 → 1 | `open_two_dialog.rb:172` | ported |

### `data/RecordAddressDialog.ui` → `lib/bustle/record_address_dialog.rb` (3 messages)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 38 | `Record Address` | 1 → 1 | `record_address_dialog.rb` | ported |
| 39 | `Address:` | 1 → 1 | `record_address_dialog.rb` | ported |
| 40 | `e.g. unix:abstract=/tmp/dbus-E5RlEB5Tzu,guid= b1c1921b62283b7b612b57305b20cc28` | 1 → 1 | `record_address_dialog.rb` | ported |

Row 40 carries a translator comment upstream (*"Just translate the 'e.g.';
leave the rest untouched."*) and the port keeps it, on the group description
that stands in for `AdwEntryRow`'s missing placeholder.

### `Bustle/UI.hs` → `lib/bustle/{window,header_bar,recorder,pdf_export}.rb` (9 messages)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 41 | `Could not read '%s'` | 1 → 1 | `window.rb:175` | ported |
| 42 | `Logged <b>%u</b> messages` | 1 → 1 | `header_bar.rb:93` | ported |
| 43 | `Recording %s&#8230;` | 1 → 1 | `recorder.rb:92` | ported |
| 44 | `Couldn't save log: ` | 1 → 1 | `window.rb:392` | ported |
| 45 | `You might want to manually recover the log from the temporary file at \"%s\".` | 1 → 1 | `window.rb:389-394` | ported |
| 46 | `Save log '%s' before closing?` | 1 → 1 | `window.rb:408` | ported |
| 47 | `If you don't save, this log will be lost forever.` | 1 → 1 | `window.rb:402` | ported |
| 48 | `Close _Without Saving` | 1 → 1 | `window.rb:416` | ported |
| 49 | `Couldn't export log as PDF: ` | 1 → 1 | `pdf_export.rb:55` | ported |

Rows 44, 45 and 49 are the ones that are normally wrong. All three are
concatenation sites upstream (`__ "Couldn't save log: " ++ …`), so the key ends
in a space that a port is very likely to tidy away or fold into a `%s`. Both
trailing spaces survive, and row 45 keeps upstream's escaped inner quotes
(`\"%s\"`) rather than converting them to Ruby's bare quotes.

### `Bustle/UI/FilterDialog.hs` → `lib/bustle/filter_dialog.rb` (1 message)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 50 | `Unticking a service hides its column in the diagram, and all messages it is involved in. That is, all methods it calls or are called on it, the corresponding returns, and all signals it emits will be hidden.` | 1 → 1 | `filter_dialog.rb:180-185` | ported |

Four Haskell string-gap continuations upstream, four Ruby literals here, same
bytes.

### `Bustle/UI/AboutDialog.hs` → `lib/bustle/about_dialog.rb` (1 message)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 51 | `Someone's favourite D-Bus profiler` | 1 → 1 | `about_dialog.rb:51` | ported |

British spelling kept.

### `Bustle/StatisticsPane.hs` → `lib/bustle/statistics_pane.rb` (9 messages)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 52 | `Frequency` | 1 → 1 | `statistics_pane.rb:145` | ported |
| 53 | `Method` | 2 → 2 | `statistics_pane.rb:147`, `:290` | ported |
| 54 | `Total` | 1 → 1 | `statistics_pane.rb:153` | ported |
| 55 | `Calls` | 1 → 1 | `statistics_pane.rb:159` | ported |
| 56 | `Mean` | 2 → 2 | `statistics_pane.rb:161`, `:177` | ported |
| 57 | `%.1f ms` | 2 → 2 | `statistics_pane.rb:155`, `:163` | ported |
| 58 | `Smallest` | 1 → 1 | `statistics_pane.rb:173` | ported |
| 59 | `Largest` | 1 → 1 | `statistics_pane.rb:181` | ported |
| 60 | `Member` | — | (row 17) | ported |

Row 53 and row 56 are each two distinct call sites for one key — `Method` as a
column title and as a tally kind, `Mean` in the durations table and in the
sizes table. Upstream reaches each key twice too, and neither was merged.

### `Bustle/Noninteractive.hs` → `lib/bustle/noninteractive.rb` (2 messages)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 61 | `Couldn't parse '%s': %s` | 1 → 1 | `noninteractive.rb:62` | ported |
| 62 | `(no interface)` | 1 → 1 | `noninteractive.rb:93` | ported |

### `data/*.desktop.in` and `data/*.appdata.xml.in` (11 messages)

| # | msgid | Uses | Port site | State |
|---|---|---|---|---|
| 63 | `Bustle` | — | (row 2) + `*.desktop.in:2` | ported |
| 64 | `Draw sequence diagrams of D-Bus activity` | 2 → 2 | `*.desktop.in:3`, `*.appdata.xml.in` | ported |
| 65 | `debug;profile;d-bus;dbus;sequence;monitor;` | 1 → 1 | `*.desktop.in:10` | ported |
| 66 | `Explore sequence diagrams of D-Bus activity` | 1 → 1 | `*.appdata.xml.in` | ported |
| 67 | `Bustle draws sequence diagrams of D-Bus activity. …` | 1 → 1 | `*.appdata.xml.in` | ported |
| 68 | `Relax with this soothing greyscale welcome page` | 1 → 1 | `*.appdata.xml.in` | ported |
| 69 | `See statistics summarizing the log` | 1 → 1 | `*.appdata.xml.in` | ported |
| 70–74 | the five release-note paragraphs upstream's `.pot` carries | 1 → 1 each | `*.appdata.xml.in` | ported |

Row 65 keeps the trailing semicolon, which a `.desktop` `Keywords` list needs
and a retyping loses. Rows 70–74 are `<release>` description paragraphs that
upstream's `.pot` does extract; the port carries them and adds its own, which
are listed as extras below.

## Extra (port-only keys — untranslated by definition)

Fifteen keys exist in the port and in no upstream catalogue, so no translator
has ever been offered them. They do not block parity, and they are strings the
port owes translators rather than strings it owes upstream.

| msgid | Why it exists | Component row |
|---|---|---|
| `_Open…` | upstream's Open item is the `gtk-open` stock label, translated by GTK itself | menus |
| `_Cancel` | upstream's `gtk-cancel` | open-a-pair, save prompt |
| `_Open` | upstream's `gtk-open` on the pair dialog | open-a-pair |
| `_Close` | upstream's InfoBar close button is GTK's own | error bar |
| `_About Bustle` | upstream's `gtk-about` | menus |
| `Main Menu` | tooltip the port added | main window |
| `Open a Log` | upstream's open chooser has no title | open dialog |
| `D-Bus logs` | file filter the port added | open dialog |
| `All files` | file filter the port added | open dialog |
| `Choose…` | `GtkFileChooserButton` showed the filename itself | open-a-pair |
| `(none chosen)` | same | open-a-pair |
| `Filter Visible Services` | upstream's filter dialog has no title | filter dialog |
| `Empty or truncated file` | loader error the port words itself | pcap loader |
| `This is the Ruby GTK4 and Libadwaita port of Bustle.` | port's own appdata | — |
| `First release of the Ruby port: …` | port's own release note | — |

Nine of the fifteen replace a string GTK or libadwaita already translates into
every language it ships. Each one is a button that reads correctly in English
and in nothing else, where upstream's read correctly everywhere — so they are
a translation regression even though the key-set check cannot call them one.
They are recorded against their components in `component-parity.md`.

## Uses

Upstream reaches 74 keys from 80 call sites (6 reused). The port reaches 88
keys from 98 call sites. No shared key is `plural` on one side and `single` on
the other — upstream has no `ngettext`/`n_()` call anywhere, which is itself
worth knowing: `Logged <b>%u</b> messages` is a singular-only msgid upstream,
and the port correctly did **not** "improve" it into a plural form, because
doing so would have changed the key.

Three keys gain call sites in the port (`Bustle` 1→2, `Save` 1→2, `Member`
1→3, `Signal` 1→3). Each is a component question, not a translation one, and
each is accounted for in the tables above.

## Verdict

`parity: false` — 1 gap, and the domain and language set match. The 15 extras
and the 4 `uses` differences do not block parity and are reported for the
ledgers that own them.
