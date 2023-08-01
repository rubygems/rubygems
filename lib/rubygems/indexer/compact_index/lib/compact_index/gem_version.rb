# frozen_string_literal: true

module Gem::Indexer::CompactIndex
  # rubocop:disable Metrics/BlockLength
  GemVersion = Struct.new(:number, :platform, :checksum, :info_checksum,
    :dependencies, :ruby_version, :rubygems_version) do
    def number_and_platform
      if platform.nil? || platform == "ruby"
        number.dup
      else
        "#{number}-#{platform}"
      end
    end

    def <=>(other)
      number_comp = number <=> other.number

      if number_comp.zero?
        [number, platform].compact <=> [other.number, other.platform].compact
      else
        number_comp
      end
    end

    def to_line
      line = number_and_platform.dup << " " << deps_line << "|checksum:#{checksum}"
      line << ",ruby:#{ruby_version_line}" if ruby_version && ruby_version != ">= 0"
      line << ",rubygems:#{rubygems_version_line}" if rubygems_version && rubygems_version != ">= 0"
      line
    end

  private

    def ruby_version_line
      join_multiple(ruby_version)
    end

    def rubygems_version_line
      join_multiple(rubygems_version)
    end

    def deps_line
      return "" if dependencies.nil?
      dependencies.map do |d|
        [d[:gem], join_multiple(d.version_and_platform)].join(":")
      end.join(",")
    end

    def join_multiple(requirements)
      requirements.split(", ").sort.join("&")
    end
  end
end
