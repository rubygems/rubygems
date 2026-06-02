# frozen_string_literal: true

module Bundler
  class Resolver
    class SpecGroup
      attr_reader :specs

      def initialize(specs)
        @specs = specs
      end

      def empty?
        @specs.empty?
      end

      def name
        @name ||= exemplary_spec.name
      end

      def version
        @version ||= exemplary_spec.version
      end

      def source
        @source ||= exemplary_spec.source
      end

      def to_specs(force_ruby_platform, most_specific_locked_platform)
        @specs.map do |s|
          lazy_spec = LazySpecification.from_spec(s)
          lazy_spec.force_ruby_platform = force_ruby_platform
          lazy_spec.most_specific_locked_platform = most_specific_locked_platform
          lazy_spec
        end
      end

      def to_s
        sorted_spec_names.join(", ")
      end

      def dependencies
        @dependencies ||= @specs.flat_map(&:expanded_dependencies).uniq.sort
      end

      def ==(other)
        sorted_spec_names == other.sorted_spec_names
      end

      def merge(other)
        return false unless equivalent?(other)

        @specs = (@specs + other.specs).uniq {|spec| spec_identity(spec) }

        true
      end

      protected

      def sorted_spec_names
        @specs.map {|spec| spec_identity(spec) }.sort
      end

      private

      def equivalent?(other)
        name == other.name && version == other.version && source == other.source && dependencies == other.dependencies
      end

      def exemplary_spec
        @specs.first
      end

      def spec_identity(spec)
        return spec.index_key if spec.respond_to?(:index_key)

        spec.full_name
      end
    end
  end
end
