# frozen_string_literal: true

module Bundler
  class CLI::Outdated
    attr_reader :options, :gems, :filter_options_patch, :sources, :strict
    attr_accessor :outdated_gems

    def initialize(options, gems)
      @options = options
      @gems = gems
      @sources = Array(options[:source])

      @filter_options_patch = options.keys & %w[filter-major filter-minor filter-patch]

      @outdated_gems = []

      # the patch level options imply strict is also true. It wouldn't make
      # sense otherwise.
      @strict = options["filter-strict"] || Bundler::CLI::Common.patch_level_options(options).any?
    end

    def run
      check_for_deployment_mode!

      gems.each do |gem_name|
        Bundler::CLI::Common.select_spec(gem_name)
      end

      Bundler.definition.validate_runtime!
      current_specs = Bundler.ui.silence { Bundler.definition.resolve }

      current_dependencies = Bundler.ui.silence do
        Bundler.load.dependencies.map {|dep| [dep.name, dep] }.to_h
      end

      definition = if gems.empty? && sources.empty?
        # We're doing a full update
        Bundler.definition(true)
      else
        Bundler.definition(gems: gems, sources: sources)
      end

      Bundler::CLI::Common.configure_gem_version_promoter(
        Bundler.definition,
        options.merge(strict: @strict)
      )

      definition_resolution = proc do
        options[:local] ? definition.resolve_with_cache! : definition.resolve_remotely!
      end

      if options[:parseable] || options[:json]
        Bundler.ui.silence(&definition_resolution)
      else
        definition_resolution.call
      end

      Bundler.ui.info "" unless options[:json]

      # Loop through the current specs
      gemfile_specs, dependency_specs = current_specs.partition do |spec|
        current_dependencies.key? spec.name
      end

      specs = if options["only-explicit"]
        gemfile_specs
      else
        gemfile_specs + dependency_specs
      end

      specs.sort_by(&:name).uniq(&:name).each do |current_spec|
        next unless gems.empty? || gems.include?(current_spec.name)

        active_spec = retrieve_active_spec(definition, current_spec)
        next unless active_spec

        next unless filter_options_patch.empty? || update_present_via_semver_portions(current_spec, active_spec, options)

        gem_outdated = Gem::Version.new(active_spec.version) > Gem::Version.new(current_spec.version)
        next unless gem_outdated || (current_spec.git_version != active_spec.git_version)

        dependency = current_dependencies[current_spec.name]
        groups = dependency && !options[:parseable] ? dependency.groups : []

        outdated_gems << {
          active_spec: active_spec,
          current_spec: current_spec,
          dependency: dependency,
          groups: groups,
        }
      end

      if outdated_gems.empty?
        if options[:json]
          Bundler.ui.table(table_headers, [])
        elsif !options[:parseable]
          Bundler.ui.info(nothing_outdated_message)
        end
      else
        relevant_gems = outdated_gems
        relevant_gems = ordered_by_group(relevant_gems) if options[:groups]
        relevant_gems = filtered_by_group(relevant_gems, options[:group]) if options[:group]

        if options[:parseable]
          print_gems_as_porcelain(relevant_gems)
        else
          Bundler.ui.table(table_headers, table_data(relevant_gems), pretty: true)
        end

        exit 1
      end
    end

    private

    def table_headers
      headers = {
        gem_name: "Gem",
        current_version: "Current",
        latest_version: "Latest",
        requested_version: "Requested",
        groups: "Groups",
      }
      headers[:path] = "Path" if Bundler.ui.debug?
      headers
    end

    def table_data(gems)
      gems.map do |gem|
        table_row_data(
          gem[:current_spec],
          gem[:active_spec],
          gem[:dependency],
          gem[:groups],
        )
      end.sort_by {|row| row[:gem_name] }
    end

    def table_row_data(current_spec, active_spec, dependency, groups)
      current_version = "#{current_spec.version}#{current_spec.git_version}"
      spec_version = "#{active_spec.version}#{active_spec.git_version}"
      dependency = dependency.requirement if dependency

      row = {
        gem_name: active_spec.name,
        current_version: current_version,
        latest_version: spec_version,
        latest_required_ruby: active_spec.required_ruby_version.to_s,
        latest_required_rubygems: active_spec.required_rubygems_version.to_s,
        requested_version: dependency.to_s,
        groups: groups,
      }
      row[:path] = loaded_from_for(active_spec).to_s if Bundler.ui.debug?
      row
    end

    def loaded_from_for(spec)
      return unless spec.respond_to?(:loaded_from)

      spec.loaded_from
    end

    def nothing_outdated_message
      if filter_options_patch.any?
        display = filter_options_patch.map do |o|
          o.sub("filter-", "")
        end.join(" or ")

        "No #{display} updates to display.\n"
      else
        "Bundle up to date!\n"
      end
    end

    def retrieve_active_spec(definition, current_spec)
      active_spec = definition.resolve.find_by_name_and_platform(current_spec.name, current_spec.platform)
      return unless active_spec

      return active_spec if strict

      active_specs = active_spec.source.specs.search(current_spec.name).select {|spec| spec.match_platform(current_spec.platform) }.sort_by(&:version)
      if !current_spec.version.prerelease? && !options[:pre] && active_specs.size > 1
        active_specs.delete_if {|b| b.respond_to?(:version) && b.version.prerelease? }
      end
      active_specs.last
    end

    def ordered_by_group(gems)
      gems.group_by {|g| g[:groups] && g[:groups].sort }.values.flatten.compact
    end

    def filtered_by_group(gems, filter)
      gems.select {|g| g[:groups]&.include?(filter.to_sym) }
    end

    def print_gems_as_porcelain(gems_list)
      gems_list.each do |gem|
        print_gem_as_porcelain(gem[:current_spec], gem[:active_spec], gem[:dependency])
      end
    end

    def print_gem_as_porcelain(current_spec, active_spec, dependency)
      spec_version = "#{active_spec.version}#{active_spec.git_version}"
      if Bundler.ui.debug?
        loaded_from = loaded_from_for(active_spec)
        spec_version += " (from #{loaded_from})" if loaded_from
      end
      current_version = "#{current_spec.version}#{current_spec.git_version}"

      if dependency&.specific?
        dependency_version = %(, requested #{dependency.requirement})
      end

      spec_outdated_info = "#{active_spec.name} (newest #{spec_version}, " \
        "installed #{current_version}#{dependency_version})"

      Bundler.ui.info spec_outdated_info.to_s.rstrip
    end

    def check_for_deployment_mode!
      return unless Bundler.frozen_bundle?
      suggested_command = if Bundler.settings.locations("frozen").keys.&([:global, :local]).any?
        "bundle config unset frozen"
      elsif Bundler.settings.locations("deployment").keys.&([:global, :local]).any?
        "bundle config unset deployment"
      end
      raise ProductionError, "You are trying to check outdated gems in " \
        "deployment mode. Run `bundle outdated` elsewhere.\n" \
        "\nIf this is a development machine, remove the " \
        "#{Bundler.default_gemfile} freeze" \
        "\nby running `#{suggested_command}`."
    end

    def update_present_via_semver_portions(current_spec, active_spec, options)
      current_major = current_spec.version.segments.first
      active_major = active_spec.version.segments.first

      update_present = false
      update_present = active_major > current_major if options["filter-major"]

      if !update_present && (options["filter-minor"] || options["filter-patch"]) && current_major == active_major
        current_minor = get_version_semver_portion_value(current_spec, 1)
        active_minor = get_version_semver_portion_value(active_spec, 1)

        update_present = active_minor > current_minor if options["filter-minor"]

        if !update_present && options["filter-patch"] && current_minor == active_minor
          current_patch = get_version_semver_portion_value(current_spec, 2)
          active_patch = get_version_semver_portion_value(active_spec, 2)

          update_present = active_patch > current_patch
        end
      end

      update_present
    end

    def get_version_semver_portion_value(spec, version_portion_index)
      version_section = spec.version.segments[version_portion_index, 1]
      version_section.to_a[0].to_i
    end
  end
end
