# Translation parity — bustle-rb

| | |
|---|---|
| Upstream | `origin/master` @ `0a8cf38` |
| Port | `ruby` @ `04031bc` |
| Upstream messages (`po/messages.pot`) | **66** |
| Port messages (marked `Bustle._()` in `lib/`) | **59** distinct, 73 call sites |
| Keys shared, byte-identical | **36** |
| Upstream keys missing from the port | **30** |
| Port keys with no upstream counterpart | **23** |
| Languages upstream | 1 (`po/LINGUAS` = `en`) |
| Languages in the port | 1 (`po/LINGUAS` = `en`) |

## The catalogue itself: carried over cleanly

`po/en.po` in the port is **byte-identical** to `origin/master:po/en.po` in
every `msgid`/`msgstr` pair — 36 entries, Will Thompson's en-dash English.
`po/LINGUAS` matches. `lib/bustle/translation.rb` reads the `.po` directly
rather than compiling `.mo` files, which is a legitimate re-expression: the
key that reaches the lookup is the same.

That is the one clean claim. The other two fail.

## What the port does not ship

- **No `po/messages.pot`.** Upstream commits one (66 messages) and regenerates
  it with `make maintainer-update-messages-pot`. The port has no `.pot`, no
  `POTFILES`-equivalent, and no extraction rule in the `Rakefile`. Nothing
  tells a translator what to translate, and nothing detects the drift this
  document is about.
- **No extraction from the data files.** Upstream's `.desktop.in` and
  `.appdata.xml.in` are templates whose strings `xgettext` pulls into the
  catalogue. The port ships `data/org.rubygtkproject.Bustle.desktop` and
  `.appdata.xml` as finished files with no `.in` and no merge step, so their
  strings are English-only by construction.

## Upstream keys the port does not produce (30)

### From the recording flow — absent because the feature is absent (11)

| msgid | Upstream source |
|---|---|
| `Record S_ession Bus` | `bustle.ui`▸`recordSession` |
| `Record S_ystem Bus` | `bustle.ui`▸`recordSystem` |
| `Record _Address…` | `bustle.ui`▸`recordAddress` |
| `Record a new log` | `bustle.ui`▸`headerRecord` tooltip |
| `_Record` | `bustle.ui`▸`headerRecord`, `RecordAddressDialog.ui` |
| `_Stop` | `bustle.ui`▸`headerStop` |
| `Save` | `bustle.ui`▸`headerSave` tooltip |
| `Logged <b>%u</b> messages` | `Bustle/UI.hs` — the header subtitle while recording |
| `Recording %s&#8230;` | `Bustle/UI.hs` |
| `Couldn't save log: ` | `Bustle/UI.hs` |
| `You might want to manually recover the log from the temporary file at \"%s\".` | `Bustle/UI/Recorder.hs` |

Plus the two `promptToSave` strings and its button, which are also
recording-only:

| msgid | Upstream source |
|---|---|
| `Save log '%s' before closing?` | `Bustle/UI.hs`▸`promptToSave` |
| `If you don't save, this log will be lost forever.` | ″ |
| `Close _Without Saving` | ″ |

Three of these (`Save log '%s' before closing?`, `If you don't save…`,
`Close _Without Saving`) are already **translated in `po/en.po`**, which the
port ships. The port carries translations for messages it never emits.

### Reworded, so the key is lost (3)

| Upstream msgid | Port msgid | Why it matters |
|---|---|---|
| `Start recording D-Bus activity with the <b>Record</b> button above\n You can also run <i>dbus-monitor --pcap</i> from the command line` | `…button above\nYou can also run…` | one byte: the space after `\n`, which `data/bustle.ui` contains. Different hash key |
| `<big><b>Waiting for D-Bus traffic; please hold…</b></big>` | `Waiting for D-Bus traffic; please hold…` | upstream's label is `use-markup`, so the markup is *inside* the msgid |
| `Couldn't export log as PDF: ` | `Couldn't export log as PDF: %s` | upstream concatenates the error after a trailing space; the port folded it into a format string |

Each of these is **two gaps**, per the skill: the upstream key is missing and
the port has an extra key nobody has translated.

### From the `.desktop`/`.appdata` templates (4 + 12)

Never extracted, because the port ships the finished files:

| msgid | Source |
|---|---|
| `Draw sequence diagrams of D-Bus activity` | desktop `Comment`, appdata `<summary>` |
| `debug;profile;d-bus;dbus;sequence;monitor;` | desktop `Keywords` |
| `org.freedesktop.Bustle` | appdata `<id>` (extracted by upstream's `xgettext` run) |
| `Bustle draws sequence diagrams of D-Bus activity. …average method call times.` | appdata `<p>` — present verbatim in the port's file, but unmarked |

Dropped outright by the port's appdata rewrite:

| msgid | What it was |
|---|---|
| `Explore sequence diagrams of D-Bus activity` | screenshot caption 1 |
| `See statistics summarizing the log` | screenshot caption 2 |
| `Relax with this soothing greyscale welcome page` | screenshot caption 3 |
| `Bustle now handles the application/vnd.tcpdump.pcap MIME type, …` | 0.7.3 release note |
| `Bustle now requires that dbus-monitor (≥ 1.9.10) and pkexec are installed on your system.` | release note |
| `Bytestrings with embedded NULs which are otherwise ASCII are now shown as ASCII strings.` | release note |
| `It's now possible to monitor the system bus …by address.` | release note |
| `The raw sender and destination for each message is now shown in the details pane.` | release note |
| `You can now explore messages while they're being recorded. …once you stop recording.` | release note |

The port removed all three `<screenshot>` elements and every upstream
`<release>`. The three captions are ordinary user-visible strings, not release
notes, and they are in the catalogue upstream.

> Note for the record: upstream's `make maintainer-update-messages-pot` runs
> `xgettext` over `data/bustle.ui`, the `.desktop.in` and the `.appdata.xml.in`
> but **not** over `data/OpenTwoDialog.ui` or `data/RecordAddressDialog.ui`.
> So `Open a Pair of Logs`, `Session bus log:`, `System bus log:`,
> `Select session bus log`, `Select system bus log`, `Record Address`,
> `Address:` and the `e.g. unix:abstract=…` placeholder are marked
> `translatable="yes"` upstream and have **never been extracted into any
> catalogue, in any language**. That is the third case in the
> `translation-parity` skill: an upstream bug, today. The port marks five of
> them in Ruby, which is the right direction for the difference to run — they
> are listed under "extra" below only because they are absent from the `.pot`,
> not because the port was wrong to mark them. Report upstream.

## Port keys with no upstream counterpart (23)

| msgid | Port source | Verdict |
|---|---|---|
| `%u byte` | `missing.rb` | **gap**: upstream calls `g_format_size()`, whose strings live in GLib's catalogue and are already translated everywhere. The port re-marks them in Bustle's domain where nobody has |
| `%u bytes` | `missing.rb` | ″ |
| `_Open…` | `menus.rb` | **gap**: upstream's item is the stock `gtk-open` |
| `_About Bustle` | `menus.rb` | **gap**: upstream's item is the stock `gtk-about` |
| `_Close` | `error_bar.rb`, `filter_dialog.rb` | **gap**: upstream's is stock `gtk-close` / an InfoBar close icon |
| `_Cancel`, `_Open` | `open_two_dialog.rb` | **gap**: upstream's are stock `gtk-cancel` / `gtk-open` |
| `Main Menu` | `header_bar.rb` | **gap**: upstream's hamburger has no tooltip |
| `Filter Visible Services` | `filter_dialog.rb` | **gap**: upstream sets the window title from an unmarked literal |
| `Open a Log`, `D-Bus logs`, `All files` | `open_dialog.rb` | **gap**: upstream's open chooser has no title and no filters |
| `(none chosen)`, `Choose…` | `open_two_dialog.rb` | **gap**: invented placeholders for the `FileChooserButton` replacement |
| `Empty or truncated file` | `pcap_loader.rb` | **gap**: upstream's pcap errors are unmarked Haskell strings |
| `Couldn't export log as PDF: %s` | `pdf_export.rb` | the reworded half of a pair above |
| `Start recording … above\nYou can…` | `welcome_page.rb` | ″ |
| `Waiting for D-Bus traffic; please hold…` | `please_hold_page.rb` | ″ |
| `Open a Pair of Logs`, `Session bus log:`, `System bus log:`, `Select session bus log`, `Select system bus log` | `open_two_dialog.rb` | **not the port's fault** — marked `translatable="yes"` upstream but missing from upstream's `.pot` (see the note above). Keep them; add them to the port's own `.pot` when one exists |

## Verdict

Three claims, three verdicts:

1. **Key sets equal** — ✗ 36 of 66 shared, 30 missing, 23 extra.
2. **Each key byte-identical** — ✗ three reworded strings, each costing two
   keys.
3. **Languages come with it** — ✓ `po/en.po` and `po/LINGUAS` carried over
   byte-identically; ✗ no `.pot`, no extraction rule, and the `.desktop` /
   `.appdata` strings were taken out of the catalogue entirely.

Upstream carries only one language, so no donated human work was destroyed
here — the loss is 30 keys the port cannot translate and 23 it would have to
get translated from scratch. That is the whole reason this is survivable, and
it is not a reason to leave it. **gap.**
