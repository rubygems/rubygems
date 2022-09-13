# frozen_string_literal: true

module Bundler
  class Resolver
    class SpecGroup
      attr_reader :name, :version, :source

      def initialize(specs)
        exemplary_spec = specs.first
        @name = exemplary_spec.name
        @version = exemplary_spec.version
        @source = exemplary_spec.source
        @specs = specs
        @platforms = specs.map(&:platform).sort_by(&:to_s).uniq
      end

      def to_specs(force_ruby_platform)
        return [] if name.end_with?("\0")

        @specs.map do |s|
          lazy_spec = LazySpecification.new(name, version, s.platform, source)
          lazy_spec.force_ruby_platform = force_ruby_platform
          lazy_spec.dependencies.replace s.dependencies
          lazy_spec
        end
      end

      def to_s
        "#{name} (#{version}) (#{@platforms.join(", ")})"
      end

      def dependencies
        @dependencies ||= @specs.map do |spec|
          __dependencies(spec) + metadata_dependencies(spec)
        end.flatten.uniq
      end

      def ==(other)
        return unless other.is_a?(SpecGroup)

        sorted_spec_names == other.sorted_spec_names
      end

      def eql?(other)
        return unless other.is_a?(SpecGroup)
        sorted_spec_names.eql?(other.sorted_spec_names)
      end

      def hash
        sorted_spec_names.hash
      end

      protected

      def sorted_spec_names
        @sorted_spec_names ||= @specs.map(&:full_name).sort
      end

      private

      def __dependencies(spec)
        dependencies = []
        spec.dependencies.each do |dep|
          next if dep.type == :development
          dependencies << Dependency.new(dep.name, dep.requirement)
        end
        dependencies
      end

      def metadata_dependencies(spec)
        return [] if spec.is_a?(LazySpecification)

        [
          metadata_dependency("Ruby", spec.required_ruby_version),
          metadata_dependency("RubyGems", spec.required_rubygems_version),
        ].compact
      end

      def metadata_dependency(name, requirement)
        return if requirement.nil? || requirement.none?

        Dependency.new("#{name}\0", requirement)
      end
    end
  end
end
