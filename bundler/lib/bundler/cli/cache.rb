# frozen_string_literal: true

module Bundler
  class CLI::Cache
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Bundler.ui.level = "warn" if options[:quiet]
      Bundler.settings.set_command_option_if_given :path, options[:path]
      Bundler.settings.set_command_option_if_given :cache_path, options["cache-path"]

      # Early exit if --no-fail-on-empty-cache-path is set and cache dir exists but is empty
      if options["no-fail-on-empty-cache-path"]
        cache_path = Bundler.settings[:cache_path] || "vendor/cache"
        cache_dir = Bundler.root.join(cache_path)
        if cache_dir.exist? && cache_dir.children.empty?
          Bundler.ui.warn "Cache directory exists but is empty. Proceeding with cache operation."
          return
        end
      end

      setup_cache_all
      install

      # TODO: move cache contents here now that all bundles are locked
      custom_path = Bundler.settings[:path] if options[:path]

      Bundler.settings.temporary(cache_all_platforms: options["all-platforms"]) do
        Bundler.load.cache(custom_path, options["no-fail-on-empty-cache-path"])
      end
    end

    private

    def install
      require_relative "install"
      options = self.options.dup
      options["local"] = false if Bundler.settings[:cache_all_platforms]
      options["no-cache"] = true
      Bundler::CLI::Install.new(options).run
    end

    def setup_cache_all
      all = options.fetch(:all, Bundler.feature_flag.cache_all? || nil)

      Bundler.settings.set_command_option_if_given :cache_all, all
    end
  end
end
