# frozen_string_literal: true

module Bundler
  class Resolver
    class SpecGroup
      include GemHelpers

      attr_accessor :name, :version, :source
      attr_accessor :activated_platforms

      def initialize(all_specs)
        @all_specs = all_specs
        exemplary_spec = all_specs.first
        @name = exemplary_spec.name
        @version = exemplary_spec.version
        @source = exemplary_spec.source

        @activated_platforms = []
        @dependencies = Hash.new do |dependencies, platforms|
          dependencies[platforms] = dependencies_for(platforms)
        end
        @specs = Hash.new do |specs, platform|
          specs[platform] = select_best_platform_match(all_specs, platform)
        end
      end

      def to_specs
        activated_platforms.map do |p|
          specs = @specs[p]
          next unless specs.any?

          specs.map do |s|
            lazy_spec = LazySpecification.new(name, version, s.platform, source)
            lazy_spec.dependencies.replace s.dependencies
            lazy_spec
          end
        end.flatten.compact.uniq
      end

      def copy_for(platforms)
        platforms.select! {|p| for?(p) }
        return unless platforms.any?

        copied_sg = self.class.new(@all_specs)
        copied_sg.activated_platforms = platforms
        copied_sg
      end

      def for?(platform)
        @specs[platform].any?
      end

      def to_s
        activated_platforms_string = sorted_activated_platforms.join(", ")
        "#{name} (#{version}) (#{activated_platforms_string})"
      end

      def dependencies_for_activated_platforms
        @dependencies[activated_platforms]
      end

      def ==(other)
        return unless other.is_a?(SpecGroup)
        name == other.name &&
          version == other.version &&
          sorted_activated_platforms == other.sorted_activated_platforms &&
          source == other.source
      end

      def eql?(other)
        return unless other.is_a?(SpecGroup)
        name.eql?(other.name) &&
          version.eql?(other.version) &&
          sorted_activated_platforms.eql?(other.sorted_activated_platforms) &&
          source.eql?(other.source)
      end

      def hash
        name.hash ^ version.hash ^ sorted_activated_platforms.hash ^ source.hash
      end

      protected

      def sorted_activated_platforms
        activated_platforms.sort_by(&:to_s)
      end

      private

      def dependencies_for(platforms)
        platforms.map do |platform|
          __dependencies(platform) + metadata_dependencies(platform)
        end.flatten
      end

      def __dependencies(platform)
        dependencies = []
        @specs[platform].first.dependencies.each do |dep|
          next if dep.type == :development
          dependencies << DepProxy.get_proxy(dep, platform)
        end
        dependencies
      end

      def metadata_dependencies(platform)
        spec = @specs[platform].first
        return [] unless spec.is_a?(Gem::Specification)
        dependencies = []
        if !spec.required_ruby_version.nil? && !spec.required_ruby_version.none?
          dependencies << DepProxy.get_proxy(Gem::Dependency.new("Ruby\0", spec.required_ruby_version), platform)
        end
        if !spec.required_rubygems_version.nil? && !spec.required_rubygems_version.none?
          dependencies << DepProxy.get_proxy(Gem::Dependency.new("RubyGems\0", spec.required_rubygems_version), platform)
        end
        dependencies
      end
    end
  end
end
