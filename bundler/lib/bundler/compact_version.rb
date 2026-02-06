# frozen_string_literal: true

module Bundler
  # A fast version representation that packs common version formats into
  # a single Integer for O(1) comparison. Follows uv's approach where
  # ~90% of real-world versions fit into a compact representation.
  #
  # Format: [16 bits major][16 bits minor][16 bits patch][16 bits pre-flag + extra]
  # This gives us major 0-65535, minor 0-65535, patch 0-65535 in a single Fixnum.
  #
  # For versions that don't fit (prerelease, > 3 segments, segments > 65535),
  # we fall back to the original Gem::Version comparison.
  class CompactVersion
    include Comparable

    MAX_SEGMENT = 0xFFFF # 65535

    attr_reader :gem_version, :packed

    def initialize(gem_version)
      @gem_version = gem_version.is_a?(Gem::Version) ? gem_version : Gem::Version.new(gem_version)
      @packed = pack(@gem_version)
    end

    def <=>(other)
      return nil unless other.is_a?(CompactVersion)

      if @packed && other.packed
        @packed <=> other.packed
      else
        @gem_version <=> other.gem_version
      end
    end

    def ==(other)
      return false unless other.is_a?(CompactVersion)
      if @packed && other.packed
        @packed == other.packed
      else
        @gem_version == other.gem_version
      end
    end

    def eql?(other)
      return false unless other.is_a?(CompactVersion)
      if @packed && other.packed
        @packed.eql?(other.packed)
      else
        @gem_version.eql?(other.gem_version)
      end
    end

    def hash
      @packed ? @packed.hash : @gem_version.hash
    end

    def prerelease?
      @gem_version.prerelease?
    end

    def segments
      @gem_version.segments
    end

    def to_s
      @gem_version.to_s
    end

    def version
      @gem_version
    end

    # Class-level cache for frequently compared versions
    @cache = {}
    @cache_mutex = Mutex.new

    def self.from_gem_version(gem_version)
      key = gem_version.to_s
      @cache_mutex.synchronize do
        @cache[key] ||= new(gem_version)
      end
    end

    def self.clear_cache!
      @cache_mutex.synchronize { @cache.clear }
    end

    private

    def pack(version)
      return nil if version.prerelease?

      segments = version.segments
      return nil if segments.length > 4
      return nil if segments.any? {|s| !s.is_a?(Integer) || s < 0 || s > MAX_SEGMENT }

      major = segments[0] || 0
      minor = segments[1] || 0
      patch = segments[2] || 0
      extra = segments[3] || 0

      (major << 48) | (minor << 32) | (patch << 16) | extra
    end
  end
end
