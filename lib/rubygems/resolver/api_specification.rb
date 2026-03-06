# frozen_string_literal: true

##
# Represents a specification retrieved via the rubygems.org API.
#
# This is used to avoid loading the full Specification object when all we need
# is the name, version, and dependencies.

class Gem::Resolver::APISpecification < Gem::Resolver::Specification
  ##
  # We assume that all instances of this class are immutable;
  # so avoid duplicated generation for performance.
  @@cache = {}
  def self.new(set, api_data)
    cache_key = [set, api_data]
    cache = @@cache[cache_key]
    return cache if cache
    @@cache[cache_key] = super
  end

  ##
  # Creates an APISpecification for the given +set+ from the rubygems.org
  # +api_data+.
  #
  # See https://guides.rubygems.org/rubygems-org-api/#misc-methods for the
  # format of the +api_data+.

  def initialize(set, api_data)
    super()

    @set = set
    @name = api_data[:name]
    @version = Gem::Version.new(api_data[:number]).freeze
    @platform = Gem::Platform.new(api_data[:platform]).freeze
    @original_platform = api_data[:platform].freeze
    @dependencies = api_data[:dependencies].map do |name, ver|
      Gem::Dependency.new(name, ver.split(/\s*,\s*/)).freeze
    end.freeze
    @required_ruby_version = Gem::Requirement.new(api_data.dig(:requirements, :ruby)).freeze
    @required_rubygems_version = Gem::Requirement.new(api_data.dig(:requirements, :rubygems)).freeze
  end

  def ==(other) # :nodoc:
    self.class === other &&
      @set          == other.set &&
      @name         == other.name &&
      @version      == other.version &&
      @platform     == other.platform
  end

  def hash
    @set.hash ^ @name.hash ^ @version.hash ^ @platform.hash
  end

  def fetch_development_dependencies # :nodoc:
    spec = source.fetch_spec Gem::NameTuple.new @name, @version, @platform

    @dependencies = spec.dependencies
  end

  def installable_platform? # :nodoc:
    Gem::Platform.match_gem? @platform, @name
  end

  def pretty_print(q) # :nodoc:
    q.group 2, "[APISpecification", "]" do
      q.breakable
      q.text "name: #{name}"

      q.breakable
      q.text "version: #{version}"

      q.breakable
      q.text "platform: #{platform}"

      q.breakable
      q.text "dependencies:"
      q.breakable
      q.pp @dependencies

      q.breakable
      q.text "set uri: #{@set.dep_uri}"
    end
  end

  ##
  # Returns a minimal Gem::Specification built from Compact Index API data.
  # Only includes name, version, platform, dependencies, required_ruby_version,
  # and required_rubygems_version. Other specification fields (e.g., files,
  # executables, authors, metadata) are not populated.

  def spec # :nodoc:
    @spec ||= build_minimal_spec_from_compact_index
  end

  def source # :nodoc:
    @set.source
  end

  private

  def build_minimal_spec_from_compact_index
    spec = Gem::Specification.new
    spec.name = @name
    spec.version = @version
    spec.platform = @platform
    spec.dependencies.replace(@dependencies)
    spec.required_ruby_version = @required_ruby_version
    spec.required_rubygems_version = @required_rubygems_version

    spec
  end
end
