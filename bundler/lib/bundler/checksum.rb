# frozen_string_literal: true

module Bundler
  class Checksum
    attr_reader :name, :version, :platform
    attr_accessor :checksum

    def initialize(name, version, platform, checksum = nil)
      @name     = name
      @version  = version
      @platform = platform || Gem::Platform::RUBY
      @checksum = checksum
    end

    def match_spec?(spec)
      name == spec.name &&
        version == spec.version &&
        platform.to_s == spec.platform.to_s
    end

    def to_lock
      out = String.new

      if platform == Gem::Platform::RUBY
        out << "  #{name} (#{version})\n"
      else
        out << "  #{name} (#{version}-#{platform})\n"
      end

      out << "    #{checksum}\n" if checksum

      out
    end
  end
end
