# frozen_string_literal: true

require_relative "rb/version"
require_relative "../bustle"

module Bustle
  # The gem's namespace, as the gemspec and `require "bustle/rb"` name it.
  #
  # `Bustle::Rb` holds nothing but the version; everything else lives directly
  # under `Bustle`, which is the name upstream's modules use. Requiring this
  # file loads the model and the backends — the half with no widgets in it —
  # which is what the test suite and `bustle --count` need.
  module Rb
  end
end
