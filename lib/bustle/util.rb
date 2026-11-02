# frozen_string_literal: true

require "fileutils"

require_relative "translation"

module Bustle
  # Odds and ends.
  #
  # Ported from upstream's Bustle/Util.hs: a warning channel for things that
  # are not worth bothering the user with (corrupt logs, names appearing
  # unheralded) and the cache directory recordings are written to before they
  # are saved. Upstream calls g_get_user_cache_dir() through the FFI; the port
  # applies the XDG rule that function implements, so the backends stay free
  # of GLib.
  module Util
    class << self
      def warn(message)
        $stderr.puts("#{Bustle._("Warning: ")}#{message}")
      end

      def cache_dir
        File.join(user_cache_dir, "bustle").tap { |dir| FileUtils.mkdir_p(dir) }
      end

      private

        def user_cache_dir
          ENV["XDG_CACHE_HOME"].then do |configured|
            if configured.nil? || configured.empty?
              File.join(Dir.home, ".cache")
            else
              configured
            end
          end
        end
    end
  end
end
