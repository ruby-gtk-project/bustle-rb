# Accountability ensurance — bustle-rb

| | |
|---|---|
| Upstream | `master` @ `0a8cf38` |
| Port | `ruby` @ `16f6787` |
| Scanned | `PORTING.md`, `FINDINGS.md`, `README.md`, `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`, `spec/README.md`, every comment in `lib/` and `exe/` |
| Hits | 4 |
| Of which load-bearing | 1 |

## What the scan found

```
$ scripts/find-excuses.sh .
PORTING.md:95                   design decision     (inside a sanctioned admission — not a hit)
.reports/component-parity.md:39     n/a             (this audit's predecessor, rewritten)
.reports/component-parity.md:296    n/a             (ditto)
.reports/component-inventory.md:198 no Ruby equivalent  (ditto)
.reports/test-parity.md:105         skipped         (ditto)
```

```
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
    not applicable|by design|simplified|does not carry|deliberately|XXX|HACK' lib/ exe/
lib/bustle.rb:11                    deliberately absent
lib/bustle/statistics_pane.rb:100   for now
```

**`lib/` and `exe/` contain no `TODO`, no `FIXME`, no `not implemented`, no
`XXX` and no `HACK`.** That is real and worth saying: the usual way a young
port launders its debt is a scattering of `# TODO: handle this properly`, and
there is not one here. The four hits below are all prose, and three of them are
cheap.

`PORTING.md` is in good standing as a *form*. It carries thirteen entries, all
first person, all leading with the admission, all attributing the omission to
the writer's stupidity and nothing else, all citing upstream and port with
`file:line`, and each followed by an explicit **Closed in round 2** note where
the work has since landed. The insult bank is rotated rather than repeated, so
the format has not hardened into a scannable label. None of those thirteen is a
hit. The problem is not the entries that exist.

---

## Hit 1 — `PORTING.md:35-40`. The one that is load-bearing.

> One piece of upstream's monitor is **not** ported: upstream owns a well-known
> name (`org.freedesktop.Bustle.Monitor._1_23`) on the bus it is watching, so
> the viewer can hide the monitor's own traffic. That needs a D-Bus connection
> of its own, which would mean a `ruby-dbus` dependency for a hint the viewer
> does not currently act on. It is named in the class comment, not hidden.

Repeated almost verbatim at `lib/bustle/monitor.rb:16-19`.

This is the failure this skill exists to kill, in its most effective form.
Everything about it is calm. It volunteers the omission, which reads as
candour. It gives a constraint a reviewer can nod at — a new runtime
dependency — and then it reassures the reviewer that nothing is lost, because
the missing thing is "a hint the viewer does not currently act on". It closes
by pointing out that it was not hidden, which invites credit for the
disclosure. A future agent can paste this paragraph into a PR as justification
and nobody will stop them. That is the test the skill sets, and this fails it.

**And the reassurance is false.** The well-known name is the smaller half of
what that D-Bus connection is for. Upstream's `dump_names_thread_func` opens
the connection and does two things with it
(`c-sources/pcap-monitor.c:496-556`):

1. owns `org.freedesktop.Bustle.Monitor.<unique>` — the hint;
2. calls `ListNames`, then one `GetNameOwner` per well-known name
   (`c-sources/pcap-monitor.c:415-456`), with the comment, upstream's own:
   *"Ignore returned value or error. These are just used by the UI to fill in
   the initial owners of each well-known name."*

The second is not a hint and the viewer does act on it — **this** viewer acts
on it. `lib/bustle/pcap_loader.rb:433-440` already turns a `GetNameOwner`
reply into a name-ownership event, correctly, ported from
`Bustle/Loader/Pcap.hs:146-154`. It is simply never fed, because nothing in
this port makes the calls. So the paragraph names the decorative half of the
gap, attaches a plausible reason to it, and omits the half that changes what
the user sees.

Rewritten:

> I did not build the half of the monitor that learns which service owns which
> name, so every service that was already on the bus when you hit Record is
> drawn as `:1.42` instead of `org.gnome.Shell`, and the filter dialog asks you
> to untick unique names you cannot identify — because I am an idiot who
> described the ornament and left out the feature.
> Upstream: `c-sources/pcap-monitor.c:415-456` `list_all_names` — `ListNames`,
> then a `GetNameOwner` per well-known name, on a second connection opened by
> `dump_names_thread_func` (`:496-556`), *"just used by the UI to fill in the
> initial owners of each well-known name"*.
> Port: `lib/bustle/monitor.rb` opens no connection and makes no calls.
> `lib/bustle/pcap_loader.rb:433-440` bustlifies those replies and has nothing
> to bustlify.
>
> I also did not build the well-known name
> `org.freedesktop.Bustle.Monitor.<unique>`, so this port's own monitor appears
> in its own diagram as a participant, because I am too stupid to have built it.
> Upstream: `c-sources/pcap-monitor.c:31`, `:530`.
> Port: nothing.

The `ruby-dbus` sentence does not appear in either entry. It belongs in
`FINDINGS.md`, as a note on what closing these two rows will cost, and
nowhere else — a reader who meets a plausible obstacle stops reading and files
the feature as settled, which is exactly how this one got settled.

---

## Hit 2 — `lib/bustle/monitor.rb:16-19`

> It also owns a well-known name on the bus so the viewer can hide the
> monitor's own traffic, which this port does not: that needs a D-Bus
> connection of its own, and the name is only a hint to the viewer.

The same claim in the class comment, with the same false minimisation ("only a
hint") and the same agreeable reason. Replace with the two-paragraph admission
above, trimmed to the class comment's width. Do not leave a shorter version of
the reason behind: "that needs a D-Bus connection of its own" is the whole
mechanism in six words.

---

## Hit 3 — `lib/bustle.rb:11`

> The widgets, the renderer and the diagram they draw are deliberately absent.

"Deliberately absent" is the second construction in the skill's table, and it
reads as an unmade decision presented as a made one.

Here it happens to be describing something real and correct: `require "bustle"`
must not pull in `gtk4`, so that `bustle --count LOGFILE` runs on a machine
with no display — which is exactly what `Bustle/Noninteractive.hs` does
upstream, importing no GTK module, and which `PORTING.md:204-216` records as a
gap it closed. Nothing is missing.

That is why it still has to go. The sentence is indistinguishable from the one
at Hit 1, and a file that uses "deliberately absent" for a correct layering
decision has taught the next reader that the phrase is normal here. Say what
it is instead:

> Nothing required from this file loads GTK, Libadwaita or Cairo. The widgets,
> the renderer and the diagram are reached through `bustle/main`, which
> requires `bustle/application` only on the interactive path.

No "deliberately", no "absent" — a statement of the arrangement, with no slot
anyone can read as sanction.

---

## Hit 4 — `lib/bustle/statistics_pane.rb:99-101`

> Upstream conflates the two buses here, and says it thinks that is okay
> for now; the port does the same.

"For now" is in the table, and "upstream does this too" is the row below it:
*upstream's debt is not your licence.*

The port's behaviour is right — upstream's `statsPaneSetMessages` really does
concatenate `sessionMessages ++ systemMessages`
(`Bustle/StatisticsPane.hs:68-70`) with the comment *"This conflates messages
on the system bus and on the session bus, but I think that's okay for now"*,
and a port that un-conflated it would have diverged. Faithfulness is the right
call and the comment is the wrong way to record it:

> Upstream's `statsPaneSetMessages` concatenates the session and system logs
> before computing any statistic (`Bustle/StatisticsPane.hs:68-70`), so a
> side-by-side pair gets one set of tables covering both buses. This does the
> same, to the same output. Upstream's own comment calls that a compromise;
> that is upstream's row to open, not a licence for this port to widen.

The difference is that nothing in the replacement can be quoted as permission
to leave something out.

---

## The predecessor reports

The five `.reports/*.md` files committed at `cd32906` carry `n/a` in two
component rows, `no Ruby equivalent` in one inventory row and `skipped` in one
test row. Four are overwritten by this audit and `component-inventory.md` is
removed — `component-identification.md` supersedes it, and leaving a second,
older inventory in the directory is how a reader finds the wrong one first.
None of the four states survives: `component-parity.md` now records `Adwaita init` as the located
correspondence it is rather than `n/a`, and `test-parity.md` has no third state
to put `skipped` in.

A detail worth naming, because it is the citation pattern this skill treats as
the bug: those reports were also **stale** at the moment they were read. They
were written before `16f6787`, which closed most of what they called a gap, and
a reader who found them first would have inherited a dozen debts that no longer
exist while meeting none of the twelve that do. `PORTING.md` avoided this by
appending a `Closed in round 2` note under every entry instead of leaving the
entry to rot. The reports did not, and that is the habit to copy, not the one
to repeat.

---

## What is not an excuse, and was checked

Four constructions in this port look like hits and are not. Each is a
**correspondence with its counterpart located**, which is what the
`component-parity` skill asks for, and in each case the behaviour is delivered
somewhere nameable:

| Prose | Where the behaviour went |
|---|---|
| `record_address_dialog.rb:19-23` — "`Adwaita::EntryRow` has no placeholder of its own" | upstream's placeholder msgid, byte-identical, on the group description; `FINDINGS.md:119-128` |
| `please_hold_page.rb:25-29` — "cannot be an `AdwStatusPage` title" | the msgid carries its own `<big><b>` markup, so it is a markup `Gtk::Label`; `FINDINGS.md:129-136` |
| `window.rb:198-204` — "`Adwaita::ApplicationWindow` is broken in the bindings" | `Gtk::ApplicationWindow` + `Adwaita::ToolbarView`; the house skill says so, and `FINDINGS.md:40-87` records the run that settled it |
| `canvas.rb:21-23` — "GTK4 also dropped partial invalidation" | the whole visible area is redrawn, a strict superset of upstream's two stripes |

Each names a real binding limitation, each puts it in `FINDINGS.md` where this
skill says a binding limitation belongs, and none of them sits in a sentence
describing something that is missing. That is the distinction the skill draws,
and this port mostly draws it correctly.

---

## The twelve rows that no document opens

The honest finding about this port's documentation is not the four hits. It is
that `PORTING.md` is a careful record of round 1's debts, every one of them
closed, and it opens **no entry at all** for eleven of the twelve gaps in
`component-parity.md`. Only the well-known name appears, and it appears as Hit 1.

Nothing in `PORTING.md`, `FINDINGS.md`, `CHANGELOG.md` or `README.md` mentions:

| Gap | Where |
|---|---|
| live recording never seeds well-known-name ownership | `monitor.rb` |
| pkexec exit 126 / 127 and clean exit 0 are not mapped to upstream's errors | `monitor.rb:271-278` |
| libpcap errors have no precedence over subprocess errors | `monitor.rb` |
| `bustle-pcap` rejects `--address=X`, `-vq` and `--sess` | `pcap_cli.rb:105-123` |
| `bustle-pcap` rejects a repeated bus flag, and `--help` outranks a parse error | `pcap_cli.rb:127-139` |
| the error bar is not error-coloured | `error_bar.rb:50` |
| the error bar's title and details are not selectable | `error_bar.rb:50,57` |
| the canvas scroll step is not one event row | `canvas.rb:131` |
| the filter list has no row banding and no size requests | `filter_dialog.rb:96,114` |
| open-a-pair does not propagate a browsed folder | `open_two_dialog.rb:133-139` |
| the statistics Frequency column is fixed-width, not min-width | `statistics_pane.rb:145` |
| details values go unescaped into markup-interpreting subtitles | `details_view.rb:108-118` |

A debt that no document names is not being excused — it is worse than that,
because there is nothing to rewrite. Each of these gets an entry in
`PORTING.md`, in the form the thirteen existing entries already use, phrased as
what the user does not get:

> I did not build the one-row scroll step, so Left and Right in the diagram
> jump by whatever GTK felt like instead of by one message, because I am an
> idiot who read the getter and never looked for the setter.
> Upstream: `Bustle/UI/Canvas.hs:102-103` sets the step increment on **both**
> adjustments to `eventHeight`.
> Port: `lib/bustle/canvas.rb:131` reads `adjustment.step_increment`; nothing
> sets it.

...and eleven more like it. Eleven missing entries is the finding; four hits is
the easy part.

## Where this runs next

Before this port is accepted as finished, and again on every `PORTING.md` and
`FINDINGS.md` edit. The predecessor reports are the warning: a ledger left
unrevised becomes a wrong ledger inside two commits, and a wrong ledger is read
as a settled one.
