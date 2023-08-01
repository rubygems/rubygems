# frozen_string_literal: true

require_relative "compact_index/gem"
require_relative "compact_index/gem_version"
require_relative "compact_index/dependency"

require_relative "compact_index/version"
require_relative "compact_index/versions_file"
require_relative "compact_index/ext/date"

module Gem::Indexer::CompactIndex
  # Formats a list of gem names, to be used on the /names endpoint.
  # @param gem_names [Array] array with gem names to be formated, in alphabetical order
  # @return [String] names on the specified format for new index /names endpoint. Example:
  #   ```ruby
  #   ---
  #   rack
  #   rails
  #   other-gem
  #   ```
  def self.names(gem_names)
    String.new("---\n") << gem_names.join("\n") << "\n"
  end

  # Returns the versions file content argumented with some extra gems
  # @param versions_file [Gem::Indexer::CompactIndex::VersionsFile] which will be used as a base response
  # @param gems [Array] an optional list of [Gem::Indexer::CompactIndex::Gem] to be appended on the end
  #   of the base file. Example:
  #   ```ruby
  #   [
  #     Gem::Indexer::CompactIndex::Gem.new("gem1", [
  #       Gem::Indexer::CompactIndex::GemVersion.new("0.9.8", "ruby", "abc123"),
  #       Gem::Indexer::CompactIndex::GemVersion.new("0.9.9", "jruby", "abc123"),
  #     ]),
  #     Gem::Indexer::CompactIndex::Gem.new("gem2", [
  #       Gem::Indexer::CompactIndex::GemVersion.new("0.9.8", "ruby", "abc123"),
  #       Gem::Indexer::CompactIndex::GemVersion.new("0.9.9", "jruby", "abc123"),
  #     ])
  #   ]
  #   ```
  # @return [String] The formated output. Example:
  #   ```ruby
  #   created_at: 2001-01-01T01:01:01-01:01
  #   ---
  #   rack 0.1.0,0.1.1,0.1.2,0.2.0,0.2.1,0.3.0,0.4.0,0.4.1,0.5.0,0.5.1,0.5.2,0.5.3 c54e4b7e14861a5d8c225283b75075f4
  #   rails 0.0.1,0.1.0 00fd5c36764f4ec1e8adf1c9adaada55
  #   sinatra 0.1.1,0.1.2,0.1.3 46f0a24d291725736216b4b6e7412be6
  #   ```
  def self.versions(versions_file, gems = nil, args = {})
    versions_file.contents(gems, args)
  end

  # Formats the versions information of a gem, to be display in the `/info/gemname` endpoint.
  #
  # @param versions_file [Gem::Indexer::CompactIndex::VersionsFile] which will be used as a base response
  # @param gems [Array] an optional list of [Gem::Indexer::CompactIndex::Gem] to be appended on the end
  #   of the base file. Example:
  #   ```ruby
  #   [
  #     Gem::Indexer::CompactIndex::GemVersion.new("1.0.1", "ruby", "abc123", "info123", [
  #       Gem::Indexer::CompactIndex::Dependency.new("foo", "=1.0.1", "abc123"),
  #       Gem::Indexer::CompactIndex::Dependency.new("bar", ">1.0, <2.0", "abc123"),
  #     ])
  #   ]
  #   ```
  #
  # @return [String] The formated output. Example:
  #   ```ruby
  #   --
  #   1.0.1 requirement:<2.0&>1.0|checksum:abc1
  #   1.0.2 requirement:<2.0&>1.0,requirement2:=1.1|checksum:abc2,ruby:>1.0,rubygems:>2.0
  #   ```
  def self.info(versions)
    versions.inject("---\n".dup) do |output, version|
      output << version.to_line << "\n"
    end
  end
end
