# frozen_string_literal: true

require_relative "bustle/rb/version"

# The model and the backends: load a log, analyse it, print it. Nothing
# required from here pulls in GTK, Libadwaita or Cairo, so `require "bustle"`
# works — and `bustle --count LOGFILE` runs — on a machine with no display and
# no gtk4 gem installed. Upstream's Bustle/Noninteractive.hs imports no GTK
# module either.
#
# The widgets, the renderer and the diagram they draw are deliberately absent.
# They are reached through `bustle/main`, which requires `bustle/application`
# only on the interactive path, and each widget file requires its own
# siblings, so the interactive half loads as one piece and the batch half
# never touches it.
require_relative "bustle/translation"
require_relative "bustle/util"
require_relative "bustle/types"
require_relative "bustle/marquee"
require_relative "bustle/variant_formatter"
require_relative "bustle/regions"
require_relative "bustle/stats"
require_relative "bustle/pcap_loader"
require_relative "bustle/loader"
require_relative "bustle/noninteractive"
require_relative "bustle/main"
