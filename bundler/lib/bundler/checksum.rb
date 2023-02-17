# frozen_string_literal: true

module Bundler
  class Checksum
    attr_reader :name, :version, :platform
    attr_accessor :checksum

    SHA256 = /\Asha256-([a-z0-9]{64}|[A-Za-z0-9+\/=]{44})\z/.freeze

    def initialize(name, version, platform, checksum = nil)
      @name     = name
      @version  = version
      @platform = platform || Gem::Platform::RUBY
      @checksum = checksum

      if @checksum && @checksum !~ SHA256
        raise ArgumentError, "invalid checksum (#{@checksum})"
      end
    end

    def self.digest_from_file_source(file_source)
      raise ArgumentError, "not a valid file source: #{file_source}" unless file_source.respond_to?(:with_read_io)

      file_source.with_read_io do |io|
        digest = Bundler::SharedHelpers.digest(:SHA256).new
        digest << io.read(16_384) until io.eof?
        io.rewind
        digest
      end
    end

    def spec_full_name
      if platform == Gem::Platform::RUBY
        "#{@name}-#{@version}"
      else
        "#{@name}-#{@version}-#{platform}"
      end
    end

    def match_spec?(spec)
      name == spec.name &&
        version == spec.version &&
        platform.to_s == spec.platform.to_s
    end

    def to_lock
      out = String.new

      if platform == Gem::Platform::RUBY
        out << "  #{name} (#{version})"
      else
        out << "  #{name} (#{version}-#{platform})"
      end

      out << " #{checksum}" if checksum
      out << "\n"

      out
    end
  end
end
