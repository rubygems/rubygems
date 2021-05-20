# frozen_string_literal: true

module Bundler
  class SourceMap
    attr_reader :sources, :dependencies

    def initialize(sources, dependencies)
      @sources = sources
      @dependencies = dependencies
    end

    def pinned_spec_names(skip = nil)
      direct_requirements.reject {|_, source| source == skip }.keys
    end

    def direct_requirements
      @direct_requirements ||= begin
        requirements = {}
        default = sources.default_source
        dependencies.each do |dep|
          dep_source = dep.source || default
          requirements[dep.name] = dep_source
        end
        requirements
      end
    end
  end
end
