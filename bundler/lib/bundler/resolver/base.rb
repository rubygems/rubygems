# frozen_string_literal: true

module Bundler
  class Resolver
    class Base
      def initialize(base, additional_base_requirements)
        @base = base
        @additional_base_requirements = additional_base_requirements
      end

      def [](name)
        @base[name]
      end

      def delete(spec)
        @base.delete(spec)
      end

      def base_requirements
        @base_requirements ||= build_base_requirements
      end

      def unlock_names(names)
        names.each do |name|
          @base.delete_by_name(name)

          @additional_base_requirements.reject! {|dep| dep.name == name }
        end

        @base_requirements = nil
      end

      private

      def build_base_requirements
        base_requirements = {}
        @base.each do |ls|
          dep = Dependency.new(ls.name, ls.version)
          base_requirements[ls.name] = dep
        end
        @additional_base_requirements.each {|d| base_requirements[d.name] = d }
        base_requirements
      end
    end
  end
end
