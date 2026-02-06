# frozen_string_literal: true

module Bundler
  module MatchMetadata
    def matches_current_metadata?
      matches_current_ruby? && matches_current_rubygems?
    end

    def matches_current_ruby?
      @required_ruby_version.satisfied_by?(Gem.ruby_version)
    end

    def matches_current_rubygems?
      @required_rubygems_version.satisfied_by?(Gem.rubygems_version)
    end

    def expanded_dependencies
      runtime_dependencies + [
        metadata_dependency("Ruby", @required_ruby_version),
        metadata_dependency("RubyGems", @required_rubygems_version),
      ].compact
    end

    def metadata_dependency(name, requirement)
      return if requirement.nil? || requirement.none?

      if name == "Ruby" && Bundler.settings[:ignore_ruby_upper_bounds]
        reqs = requirement.requirements.reject { |op, _| op == "<" || op == "<=" }
        return if reqs.empty?
        requirement = Gem::Requirement.new(reqs.map { |op, v| "#{op} #{v}" })
      end

      Gem::Dependency.new("#{name}\0", requirement)
    end
  end
end
