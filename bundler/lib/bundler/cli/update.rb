# frozen_string_literal: true

module Bundler
  class CLI::Update
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    # Parse gem names and version constraints from command line arguments
    # Supports both formats:
    # - "gem_name" (updates to latest version)
    # - "gem_name, version_constraint" (updates to specific version constraint)
    # Gemfile-style: "rails, >=8.0.2" or "rails, >=3.0, <4.0"
    def parse_gem_constraints(gems)
      gems.each_with_object({}) do |gem_str, constraints|
        if gem_str.include?(",")
          parts = gem_str.split(",", 2)
          name = parts[0].strip
          version_constraints = parts[1].strip
          if version_constraints.include?(",")
            constraints[name] = version_constraints.split(",").map(&:strip)
          else
            constraints[name] = [version_constraints]
          end
        else
          constraints[gem_str] = [">= 0"]
        end
      end
    end

    def run
      Bundler.ui.level = "warn" if options[:quiet]

      update_bundler = options[:bundler]

      Bundler.self_manager.update_bundler_and_restart_with_it_if_needed(update_bundler) if update_bundler

      Plugin.gemfile_install(Bundler.default_gemfile) if Bundler.feature_flag.plugins?

      sources = Array(options[:source])
      groups  = Array(options[:group]).map(&:to_sym)

      full_update = gems.empty? && sources.empty? && groups.empty? && !options[:ruby] && !update_bundler

      if full_update && !options[:all]
        if Bundler.feature_flag.update_requires_all_flag?
          raise InvalidOption, "To update everything, pass the `--all` flag."
        end
        SharedHelpers.major_deprecation 4, "Pass --all to `bundle update` to update everything"
      elsif !full_update && options[:all]
        raise InvalidOption, "Cannot specify --all along with specific options."
      end

      conservative = options[:conservative]

      # Initialize gem_names and gem_constraints
      gem_constraints = {}
      gem_names = []

      if full_update
        if conservative
          Bundler.definition(conservative: conservative)
        else
          Bundler.definition(true)
        end
      else
        unless Bundler.default_lockfile.exist?
          raise GemfileLockNotFound, "This Bundle hasn't been installed yet. " \
            "Run `bundle install` to update and install the bundled gems."
        end

        # Parse gem constraints if any gems are specified
        gem_constraints = gems.any? ? parse_gem_constraints(gems) : {}
        gem_names = gem_constraints.keys

        Bundler::CLI::Common.ensure_all_gems_in_lockfile!(gem_names)

        if groups.any?
          deps = Bundler.definition.dependencies.select {|d| (d.groups & groups).any? }
          gem_names.concat(deps.map(&:name))
        end

        Bundler.definition(gems: gem_constraints, sources: sources, ruby: options[:ruby],
                           conservative: conservative,
                           bundler: update_bundler)
      end

      Bundler::CLI::Common.configure_gem_version_promoter(Bundler.definition, options)

      Bundler::Fetcher.disable_endpoint = options["full-index"]

      opts = options.dup
      opts["update"] = true
      opts["local"] = options[:local]
      opts["force"] = options[:redownload] if options[:redownload]

      Bundler.settings.set_command_option_if_given :jobs, opts["jobs"]

      Bundler.definition.validate_runtime!

      if locked_gems = Bundler.definition.locked_gems
        previous_locked_info = locked_gems.specs.reduce({}) do |h, s|
          h[s.name] = { spec: s, version: s.version, source: s.source.identifier }
          h
        end
      end

      installer = Installer.install Bundler.root, Bundler.definition, opts
      Bundler.load.cache if Bundler.app_cache.exist?

      if CLI::Common.clean_after_install?
        require_relative "clean"
        Bundler::CLI::Clean.new(options).run
      end

      if locked_gems && gem_names.any?
        gem_names.each do |name|
          locked_info = previous_locked_info[name]
          next unless locked_info

          locked_spec = locked_info[:spec]
          new_spec = Bundler.definition.specs[name].first
          unless new_spec
            unless locked_spec.installable_on_platform?(Bundler.local_platform)
              Bundler.ui.warn "Bundler attempted to update #{name} but it was not considered because it is for a different platform from the current one"
            end

            next
          end

          locked_source = locked_info[:source]
          new_source = new_spec.source.identifier
          next if locked_source != new_source

          new_version = new_spec.version
          locked_version = locked_info[:version]
          if new_version < locked_version
            Bundler.ui.warn "Note: #{name} version regressed from #{locked_version} to #{new_version}"
          elsif new_version == locked_version
            Bundler.ui.warn "Bundler attempted to update #{name} but its version stayed the same"
          end
        end
      end

      Bundler.ui.confirm "Bundle updated!"
      Bundler::CLI::Common.output_without_groups_message(:update)
      Bundler::CLI::Common.output_post_install_messages installer.post_install_messages

      Bundler::CLI::Common.output_fund_metadata_summary
    end
  end
end
