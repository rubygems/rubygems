# frozen_string_literal: true

module Bundler
  module MatchMetadata
    def matches_current_metadata?
      matches_current_ruby? && matches_current_rubygems?
    end

    def matches_current_ruby?
      requirement = if Bundler.settings[:ignore_ruby_upper_bounds]
        remove_upper_bounds(@required_ruby_version)
      else
        @required_ruby_version
      end
      requirement.satisfied_by?(Gem.ruby_version)
    end

    def matches_current_rubygems?
      requirement = if Bundler.settings[:ignore_rubygems_upper_bounds]
        remove_upper_bounds(@required_rubygems_version)
      else
        @required_rubygems_version
      end
      requirement.satisfied_by?(Gem.rubygems_version)
    end

    def expanded_dependencies
      runtime_dependencies + [
        metadata_dependency("Ruby", @required_ruby_version),
        metadata_dependency("RubyGems", @required_rubygems_version),
      ].compact
    end

    def metadata_dependency(name, requirement)
      return if requirement.nil? || requirement.none?

      if (name == "Ruby" && Bundler.settings[:ignore_ruby_upper_bounds]) ||
         (name == "RubyGems" && Bundler.settings[:ignore_rubygems_upper_bounds])
        requirement = remove_upper_bounds(requirement)
        return if requirement.none?
      end

      Gem::Dependency.new("#{name}\0", requirement)
    end

    private

    def remove_upper_bounds(requirement)
      filtered = requirement.requirements.reject {|op, _| ["<", "<="].include?(op) }
      if filtered.empty?
        Gem::Requirement.default
      else
        Gem::Requirement.new(filtered.map {|op, v| "#{op} #{v}" })
      end
    end
  end
end
