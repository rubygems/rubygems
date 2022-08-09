# frozen_string_literal: true

module Bundler
  module FetchMetadata
    def required_ruby_version
      @required_ruby_version ||= _remote_specification.required_ruby_version
    end

    def required_rubygems_version
      # A fallback is included because the original version of the specification
      # API didn't include that field, so some marshalled specs in the index have it
      # set to +nil+.
      @required_rubygems_version ||= _remote_specification.required_rubygems_version || Gem::Requirement.default
    end
  end
end
