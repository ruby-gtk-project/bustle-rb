# Findings

Questions about the Ruby GTK4 / Libadwaita bindings that this port has run
into, and what is and is not known about each. Anything here that is a guess
says so.

## The environment this round was written in

No gems are installed in this checkout and there is no network to install
them:

```
$ ruby -e 'require "gtk4"'
cannot load such file -- gtk4 (LoadError)
$ ruby -e 'require "glib2"'
cannot load such file -- glib2 (LoadError)
$ bundle exec rspec --version
bundler: command not found: rspec
$ which msgfmt rake
msgfmt not found
rake: can't find gem rake
```

So, concretely, for round 2:

- **The backend is verified.** `require "bustle"` loads, `bustle --count`
  runs, `lib/bustle/monitor.rb` records the real session bus
  (`bustle-pcap -v /tmp/rec.bustle` logged two messages, stopped cleanly on
  `SIGINT`, and the port's own `PcapLoader` read the resulting file back), and
  all 23 ported specs pass against the real `lib/` — executed with a
  throwaway RSpec stand-in, since `rspec` itself is not installed.
- **Nothing with a widget in it is verified.** Every file that requires
  `adwaita` or `gtk4` has had `ruby -c` run over it and nothing more. That
  includes `header_bar.rb`, `record_address_dialog.rb`, `window.rb`,
  `recorder.rb` and `statistics_pane.rb`. `ruby -c` proves nothing about a UI,
  and the `ruby-gtk-testing` skill cannot be used without the gems.

The questions below are the ones a run would settle.

## `Adwaita::ApplicationWindow` and the double titlebar

`.claude/skills/ruby-gtk/SKILL.md` and `references/adwaita-quirks.md` both say
`Adwaita::Application` and `Adwaita::ApplicationWindow` are broken in the Ruby
bindings and that `Gtk::Application` + `Gtk::ApplicationWindow` should be used
instead.

Round 1 built the window on `Adwaita::ApplicationWindow` and justified it in a
code comment: that `Gtk::ApplicationWindow` "draws a titlebar of its own above
the Adwaita header bar, leaving the window with two of them". **No
reproduction was recorded and the app was never run.** The comment has been
deleted and `Window#window` is now a `Gtk::ApplicationWindow` whose child is
an `Adwaita::ToolbarView`.

**Open question.** Is the double titlebar real?

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

**Open question.** Does `AdwBanner` have a `use-markup` property in the
libadwaita this port will run against?

`AdwBanner` gained `use-markup` in libadwaita 1.7. Against anything older the
property does not exist and `banner.use_markup = true` raises
`NoMethodError`, which would take the error bar — and therefore every failed
load — down with it. The port has not been run, so which it is here is
unknown.

If it turns out to be absent, the options are to escape the markup and lose
the bold title, or to move the title into the dim label underneath beside the
details, where markup already works.

## `GLib.format_size`

`lib/bustle/missing.rb` now calls `GLib.format_size(size)` rather than
reimplementing `g_format_size()`, so the size columns keep GLib's own
translations instead of two invented msgids with hard-coded English suffixes.

**Open question, lower stakes.** `GLib.format_size` is the glib2 gem's binding
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
