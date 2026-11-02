# frozen_string_literal: true

require_relative "bustle/rb/version"

# The model and the backends, which have no widgets in them and can be used
# on their own: load a log, render it, analyse it.
require_relative "bustle/translation"
require_relative "bustle/util"
require_relative "bustle/missing"
require_relative "bustle/types"
require_relative "bustle/marquee"
require_relative "bustle/variant_formatter"
require_relative "bustle/regions"
require_relative "bustle/stats"
require_relative "bustle/pcap_loader"
require_relative "bustle/loader"
require_relative "bustle/noninteractive"

# The widgets, which need GTK and Libadwaita.
require_relative "bustle/diagram"
require_relative "bustle/renderer"
require_relative "bustle/canvas"
require_relative "bustle/details_view"
require_relative "bustle/statistics_pane"
require_relative "bustle/welcome_page"
require_relative "bustle/please_hold_page"
require_relative "bustle/error_bar"
require_relative "bustle/menus"
require_relative "bustle/header_bar"
require_relative "bustle/about_dialog"
require_relative "bustle/open_dialog"
require_relative "bustle/open_two_dialog"
require_relative "bustle/filter_dialog"
require_relative "bustle/pdf_export"
require_relative "bustle/window"
require_relative "bustle/application"
require_relative "bustle/main"
