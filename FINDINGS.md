# Findings

Questions about the Ruby GTK4 / Libadwaita bindings that this port has run
into, and what is and is not known about each. Anything here that is a guess
says so.

## The environment this port is verified in

The fork's dev shell carries the whole stack — ruby 3.4.9, gtk4 4.3.9,
adwaita 4.3.9, GTK 4.22.4, rubocop, rspec, gettext's `msgfmt`, `dbus-daemon`
and `dbus-monitor` — and there is no display, so every run goes through a
virtual one:

```
nix develop --command xvfb-run -a ruby exe/bustle
nix develop --command xvfb-run -a ruby test/drive_all.rb
nix develop --command dbus-run-session -- xvfb-run -a ruby test/drive_recording.rb
```

Note `Gtk::VERSION` does not exist; the constant is `Gtk::Version::STRING`.

What that buys, concretely:

- **The backend is verified.** `require "bustle"` loads, `bustle --count`
  runs, `lib/bustle/monitor.rb` records the real session bus under
  `dbus-run-session`, and the port's own `PcapLoader` reads the resulting file
  back.
- **The widgets are verified too.** `test/drive_all.rb` builds every window,
  page and dialog in `.reports/component-inventory.md` under a real GTK
  display, drives them by emitting the signals a user's clicks and keystrokes
  would, and screenshots the result: 299 checks over all 22 components. The
  spec suite is 24 examples under the same display.

The sections below record what driving that way settled, and the handful of
things it could not reach.

## `Adwaita::ApplicationWindow` and the double titlebar

`.claude/skills/ruby-gtk/SKILL.md` and `references/adwaita-quirks.md` both say
`Adwaita::Application` and `Adwaita::ApplicationWindow` are broken in the Ruby
bindings and that `Gtk::Application` + `Gtk::ApplicationWindow` should be used
instead.

Round 1 built the window on `Adwaita::ApplicationWindow` and justified it in a
code comment: that `Gtk::ApplicationWindow` "draws a titlebar of its own above
the Adwaita header bar, leaving the window with two of them". **No
reproduction was ever recorded for that claim.** The comment has been
deleted and `Window#window` is now a `Gtk::ApplicationWindow` whose child is
an `Adwaita::ToolbarView`.

**Was an open question.** Is the double titlebar real? Settled below: no.

What is known: in GTK4 a `GtkApplicationWindow` has a titlebar only if one is
set, and no titlebar is the default — an `AdwToolbarView` added as the
window's *child*, with an `AdwHeaderBar` in its top bar, is the arrangement
libadwaita's own documentation recommends and should produce exactly one
header bar. A second titlebar would mean either that the Ruby bindings install
a default titlebar, or that round 1 set the header bar as the window's
`titlebar` *and* put one in a toolbar view.

**Reproduction to run when the gems are available** (does not need Bustle):

```ruby
require "adwaita"

app = Gtk::Application.new("org.example.titlebar", :default_flags)
app.signal_connect("activate") do
  win = Gtk::ApplicationWindow.new(app)
  view = Adwaita::ToolbarView.new
  view.add_top_bar(Adwaita::HeaderBar.new)
  view.content = Gtk::Label.new("one titlebar or two?")
  win.child = view
  win.present
end
app.run([])
```

If two bars appear, record it here with a screenshot and the libadwaita
version. The fix is then to hide the window's own titlebar, or to move the
header bar to `win.titlebar=` instead of into the toolbar view — **not** to go
back to `Adwaita::ApplicationWindow`, which the skill records as broken for a
different reason (type-interface errors when the window is constructed from a
`Gtk::Application`).

## `Adwaita::Banner#use_markup`

`lib/bustle/error_bar.rb` sets `banner.use_markup = true` and then feeds the
banner Pango markup, because upstream's `errorBarTitle` is a `GtkLabel` with
markup in it.

**Was an open question.** Does `AdwBanner` have a `use-markup` property in
the libadwaita this port runs against? Settled below: it does not, and the
error bar no longer uses an `AdwBanner`.

`AdwBanner` gained `use-markup` in libadwaita 1.7. Against anything older the
property does not exist and `banner.use_markup = true` raises
`NoMethodError`, which would take the error bar — and therefore every failed
load — down with it.

If it turns out to be absent, the options are to escape the markup and lose
the bold title, or to move the title into the dim label underneath beside the
details, where markup already works.

## `GLib.format_size`

`lib/bustle/missing.rb` now calls `GLib.format_size(size)` rather than
reimplementing `g_format_size()`, so the size columns keep GLib's own
translations instead of two invented msgids with hard-coded English suffixes.

**Was an open question, lower stakes.** `GLib.format_size` is the glib2 gem's binding
for `g_format_size()`; the exact spelling has not been exercised here because
`glib2` is not installed. If it is missing, the sibling to try is
`GLib::Format.size`. This is a one-line fix in one file, and it is reached only
by the statistics pane's three size columns.

## `Adwaita::EntryRow` has no placeholder

Established, not a question: `AdwEntryRow` has no `placeholder-text` property
— an empty row shows its title instead. Upstream's record-address dialog has
both a label ("Address:") and a placeholder (the `e.g. unix:abstract=…`
example, whose translator comment says to translate only the "e.g."). The port
keeps both strings by making the title the label and the enclosing
`AdwPreferencesGroup`'s description the example. Recorded in
`lib/bustle/record_address_dialog.rb`.

## `Adwaita::WindowTitle` does not take markup

Established, not a question. `AdwWindowTitle`'s title and subtitle are plain
text. Upstream's recording subtitle is `Logged <b>%u</b> messages` — the markup
is inside the msgid — and its please-hold label is
`<big><b>Waiting for D-Bus traffic; please hold…</b></big>`, likewise. Both are
`Gtk::Label`s in this port for that reason, which is also what they are
upstream.

## Icons are not found when the app runs out of its own source tree

Established by driving the app, not by reading the code: the welcome page drew
a broken-image placeholder where the Bustle logo should be, and the about
dialog had no logo either. Upstream installs `data/icons` into the prefix and
leaves the rest to the icon theme; an uninstalled copy — which is how
`ruby exe/bustle` and the drive scripts run it — is on nobody's
`XDG_DATA_DIRS`, so `Gtk::IconTheme` never sees
`org.rubygtkproject.Bustle-symbolic`. `Bustle::Application#install_icons` now
adds the shipped `data/icons` to the theme's search path on activate, which is
a no-op for an installed copy. `test/drive_bustle.rb` asserts
`IconTheme#has_icon?` for both the symbolic and the full-colour name, because
a missing icon is otherwise silent.

## `GLib.format_size` works

Resolved: the open question in the `GLib.format_size` section above. The
statistics pane's three size columns render real figures under
`test/drive_bustle.rb`, so the glib2 spelling is right as written.

## No binding gaps were hit

Driving every component in `.reports/component-inventory.md` turned up no
missing or broken ruby-gnome binding. In particular `Gtk::Application#
get_accels_for_action`, `Gtk::EventControllerKey`'s and `Gtk::GestureClick`'s
`signal_emit`, `Adwaita::AlertDialog#get_response_appearance` and
`Gtk::IconTheme#add_search_path` all behave as the C API documents. The one
thing that genuinely cannot be driven is `Gtk::FileDialog`: GTK4 made it a
one-shot async chooser with no signals, so the four dialogs that wrap one are
tested by asserting the chooser's configuration and calling the code its
callback calls.

## `Gtk::FileChooser` has no signals, so a browsed folder cannot be followed

Settled, and it costs the port a behaviour. Upstream's Open-a-Pair dialog
embeds two `GtkFileChooserButton`s and connects `current-folder-changed` on
each (`Bustle/UI/OpenTwoDialog.hs:36-44`), so navigating to a folder in one
chooser — before any file is picked — moves the other chooser there, as long
as that one is still empty.

GTK4 removed every signal from `GtkFileChooser` and replaced the embedded
chooser with `GtkFileDialog`, which is a one-shot modal: it is handed an
`initial-folder`, it runs, and it returns a `GFile` or an error. There is no
object to watch while it is open, no `current-folder` property to read back
and nothing emitted while the user navigates. Verified on the bindings here:
`Gtk::FileDialog.new.signal_connect("current-folder-changed")` raises
`GLib::NoSignalError: no such signal: current-folder-changed`, and the only
folder accessors the object has are `initial_folder`, `initial_folder=`,
`set_initial_folder` and the `select_folder` family — nothing to watch and
nothing to read back.

So the only moment the port can observe is the moment a file is chosen, and
the only folder it learns is that file's parent. `OpenTwoDialog` remembers it
for both choosers — its own, so re-opening returns to where the user was, and
the other one while the other is still empty, which is upstream's guard. What
is not recovered is the case upstream's signal exists for: browse, change
your mind, dismiss. Getting that back would mean building the chooser out of
`GtkFileChooserWidget`-era parts that GTK4 no longer exposes, or writing a
file browser by hand; neither is worth it for a dialog that opens two logs.
This is why the gap is expensive, not why it is closed: it is open, and
`lib/bustle/open_two_dialog.rb` says so in the first person.

## There is no double titlebar

Resolved: the open question in the `Adwaita::ApplicationWindow` section above.
Driven against GTK 4.22.4 and adwaita 4.3.9, a `Gtk::ApplicationWindow` whose
child is an `Adwaita::ToolbarView` with an `Adwaita::HeaderBar` in its top bar
reports `window.titlebar == nil` and draws exactly one header bar. The Ruby
bindings install no default titlebar, so round 1's justification for
`Adwaita::ApplicationWindow` was wrong and the arrangement `lib/bustle/window.rb`
now uses — the one libadwaita's own documentation recommends — is correct.

## `Adwaita::Banner` has no `use_markup`, and the error bar no longer wants one

Resolved, the other way round from the guess above. The property really is
absent here:

```
$ Adwaita::Banner.new("x").use_markup = true
NoMethodError: undefined method 'use_markup' for an instance of Adwaita::Banner
```

`AdwBanner` gained `use-markup` in libadwaita 1.7 and these bindings are
older, so the round-1 error bar would have raised on the first failed load.
It is moot now for a different reason: `AdwBanner` was the wrong widget for
upstream's `GtkInfoBar` anyway — one line of unselectable accent-coloured text
in place of a bold title, small details and selectable text. `lib/bustle/error_bar.rb`
is a `Gtk::Box` in the error colours with upstream's two `Gtk::Label`s inside
it, and `Gtk::Label#use_markup` is not in question.
