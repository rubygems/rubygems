# frozen_string_literal: true

##
# Platform-specific gem matching for Ruby platform tags.
#
# The Gem::Platform::Specific class extends traditional platform matching with
# detailed Ruby environment information, enabling precise gem selection based on
# interpreter type, ABI version, and platform details. This is particularly
# useful for gems with native extensions or platform-specific behavior.
#
# == When to Use Gem::Platform::Specific vs Gem::Platform
#
# Use Gem::Platform::Specific when you need:
# - Precise Ruby interpreter and ABI version matching
# - Linux libc version detection (glibc vs musl)
# - Wheel-format compatibility matching
# - Advanced platform tag generation for gem publishing
#
# Use traditional Gem::Platform for:
# - Simple platform string matching ("x86_64-linux")
# - Legacy compatibility requirements
# - Basic platform detection without Ruby environment details
#
# == Basic Usage
#
#   # Create from current environment
#   specific = Gem::Platform::Specific.local
#   specific.platform          #=> #<Gem::Platform:0x... @cpu="x86_64", @os="linux", @version="gnu">
#   specific.ruby_engine       #=> "ruby"
#   specific.ruby_version      #=> "3.3.1"
#   specific.libc_type         #=> "glibc"
#
#   # Create for specific platform and Ruby version
#   specific = Gem::Platform::Specific.new(
#     "x86_64-linux",
#     ruby_engine: "ruby",
#     ruby_version: "3.2.0",
#     abi_version: "3.2.0"
#   )
#
# == Wheel Compatibility
#
# Generate wheel-compatible tags for gem publishing:
#
#   specific = Gem::Platform::Specific.local
#   specific.each_possible_match do |abi_tag, platform_tag|
#     puts "#{abi_tag}-#{platform_tag}"
#   end
#   # Output:
#   # cr33-x86_64_linux
#   # rb33-x86_64_linux
#   # rb3-x86_64_linux
#   # any-x86_64_linux
#   # any-any
#
# == Linux libc Detection
#
# On Linux systems, automatically detects libc implementation:
#
#   # On glibc system
#   specific = Gem::Platform::Specific.local
#   specific.libc_type     #=> "glibc"
#   specific.libc_version  #=> [2, 31]
#
#   # On musl system
#   specific = Gem::Platform::Specific.local
#   specific.libc_type     #=> "musl"
#   specific.libc_version  #=> [1, 2]
#
# == Performance Characteristics
#
# - Platform tag generation is cached after first computation
# - Linux libc detection executes shell commands once per process
# - Thread-safe for read operations after initialization
# - Memory usage scales with number of generated platform tags
#
# == Migration from Gem::Platform
#
#   # Before
#   platform = Gem::Platform.local
#   compatible = platform === other_platform
#
#   # After
#   specific = Gem::Platform::Specific.local
#   compatible = specific === other_platform
#   # Provides same compatibility but with enhanced matching
#
# This class provides detailed platform and Ruby environment information
# to enable precise gem matching based on interpreter, ABI, and platform details.

class Gem::Platform::Specific
  attr_reader :platform, :ruby_engine, :ruby_engine_version, :ruby_version, :abi_version, :libc_type, :libc_version,
    :ruby_abi_tag, :platform_tags, :rb_version_range, :normalized_platform_tags

  ##
  # Creates a new Gem::Platform::Specific instance.
  #
  # [+platform+] Platform string or Gem::Platform object (e.g., "x86_64-linux")
  # [+ruby_engine+] Ruby engine name ("ruby", "jruby", "truffleruby")
  # [+ruby_engine_version+] Engine version (e.g., "3.3.1")
  # [+ruby_version+] Ruby language version (e.g., "3.3.1")
  # [+abi_version+] ABI version for binary compatibility (e.g., "3.3.0")
  # [+libc_type+] Linux libc implementation ("glibc" or "musl")
  # [+libc_version+] libc version as [major, minor] array
  #
  # If ruby environment parameters are omitted, some features (like ABI tag
  # generation) will not be available. Use .local for current environment.
  def initialize(platform, ruby_engine: nil, ruby_engine_version: nil, ruby_version: nil, abi_version: nil, libc_type: nil, libc_version: nil)
    @platform = platform.is_a?(Gem::Platform) ? platform : Gem::Platform.new(platform)
    @ruby_engine = ruby_engine
    @ruby_engine_version = ruby_engine_version
    @ruby_version = ruby_version
    @abi_version = abi_version
    @libc_type = libc_type
    @libc_version = libc_version
    @ruby_abi_tag = Gem::Platform::Specific.generate_ruby_abi_tag(ruby_engine, ruby_engine_version, ruby_version, abi_version)

    # Precompute expensive arrays
    @platform_tags = _platform_tags.freeze
    @rb_version_range = _rb_version_range.freeze
    @normalized_platform_tags = @platform_tags.map {|platform_str| Gem::Platform::Wheel.normalize_tag_set(platform_str) }.freeze
  end

  def to_s
    components = [@platform.to_s]
    # Always include version as the first attribute for format tracking
    components << "v:1"
    components << "engine:#{@ruby_engine}" if @ruby_engine
    components << "engine_version:#{@ruby_engine_version}" if @ruby_engine_version
    components << "ruby_version:#{@ruby_version}" if @ruby_version
    components << "abi_version:#{@abi_version}" if @abi_version
    components << "libc_type:#{@libc_type}" if @libc_type
    if @libc_version
      # Serialize libc_version array as dot-joined string to avoid parsing issues
      components << "libc_version:#{@libc_version.join(".")}"
    end
    components.join(" ")
  end

  def ==(other)
    other.is_a?(self.class) &&
      @platform == other.platform &&
      @ruby_engine == other.ruby_engine &&
      @ruby_engine_version == other.ruby_engine_version &&
      @ruby_version == other.ruby_version &&
      @abi_version == other.abi_version &&
      @libc_type == other.libc_type &&
      @libc_version == other.libc_version
  end
  alias_method :eql?, :==

  def hash
    [@platform, @ruby_engine, @ruby_engine_version, @ruby_version, @abi_version, @libc_type, @libc_version].hash
  end

  ##
  # Generates wheel-compatible platform tags in priority order.
  #
  # Yields [abi_tag, platform_tag] pairs in descending compatibility order,
  # from most specific (exact interpreter + platform match) to most general
  # (any-any fallback).
  #
  # Tag generation follows this priority order:
  # 1. Current interpreter + specific ABI + platform variations (e.g., cr34_static-arm64_darwin)
  # 2. Generic Ruby versions + platform variations (e.g., rb34-arm64_darwin, rb3-arm64_darwin)
  # 3. Any ABI + platform variations (e.g., any-arm64_darwin)
  # 4. Universal fallback (any-any)
  #
  # This is designed for wheel format compatibility but can be used for any
  # tag-based platform matching system.
  #
  #   specific = Gem::Platform::Specific.local
  #   tags = specific.each_possible_match.take(5)
  #   tags.each { |abi, platform| puts "#{abi}-#{platform}" }
  #   # cr33-x86_64_linux
  #   # rb33-x86_64_linux
  #   # rb3-x86_64_linux
  #   # any-x86_64_linux
  #   # any-any
  #
  # Returns an Enumerator if no block is given.
  def each_possible_match(&)
    return enum_for(__method__) unless block_given?

    # For ruby platform, the `platform` tag should only ever be `any`, but the ruby tag should still take into account the interpreter/ruby version
    if platform == Gem::Platform::RUBY
      yield ["any", "any"]
      return
    end

    # Use precomputed normalized platform tags
    platform_tags = normalized_platform_tags

    # 1. Most specific: exact interpreter ABI with all platform variations
    # Only generates tags for the current Ruby version (no stable ABI like Python)
    if ruby_engine && ruby_engine_version && ruby_version && abi_version
      if ruby_abi_tag
        platform_tags.each do |platform_tag|
          yield [ruby_abi_tag, platform_tag]
        end
      end
    end

    # 2. Generic Ruby version tags with platform variations (backward compatibility)
    # Generate rb* tags for backward compatibility, but only the versions that weren't already covered
    rb_version_range.each do |version|
      platform_tags.each do |platform_tag|
        yield [version, platform_tag]
      end
    end

    # Also generate "any" platform versions for Ruby versions
    rb_version_range.each do |version|
      yield [version, "any"]
    end

    # 3. Any ABI with platform variations (broad compatibility)
    platform_tags.each do |platform_tag|
      yield ["any", platform_tag]
    end

    # 4. Universal fallback (maximum compatibility)
    yield ["any", "any"]
  end

  # Generate platform tags specific to this environment, including manylinux/musllinux tags
  def _platform_tags
    if platform.nil? || platform == Gem::Platform::RUBY
      return []
    end

    tags = []

    # Generate base platform tags first
    if platform.os == "darwin" && platform.version
      _darwin_platform_tags(tags)
    else
      # Non-Darwin platforms: use existing logic
      tags << platform.to_s
      if platform.cpu != "universal"
        tags << ["universal", platform.os, platform.version].compact.join("-")
      end

      # For Linux platforms with glibc suffix, also generate version without suffix for broader compatibility
      if platform.os == "linux" && platform.version == "gnu"
        tags << [platform.cpu, platform.os].compact.join("-")
        if platform.cpu != "universal"
          tags << ["universal", platform.os].compact.join("-")
        end
      end

      # Generate manylinux/musllinux tags if we have libc information
      if platform.os == "linux" && libc_type && libc_version
        case libc_type
        when "glibc"
          tags.concat(Gem::Platform::Manylinux.platform_tags([platform.cpu], libc_version).to_a)
        when "musl"
          tags.concat(Gem::Platform::Musllinux.platform_tags([platform.cpu], libc_version).to_a)
        end
      end

      if platform.version && platform.os != "linux"
        tags << [platform.cpu, platform.os].compact.join("-")
      end

      tags << platform.os if (platform.cpu || platform.version) && platform.os != "linux"
    end

    tags
  end

  # Generate Ruby version range tags (rb33, rb3, rb32, etc.)
  def _rb_version_range
    return [] unless ruby_version

    tags = []
    parts = ruby_version.split(".").map!(&:to_i)
    tags << "rb#{parts[0, 2].join}" if parts.size > 1
    tags << "rb#{parts[0]}"

    if parts.size > 1
      parts[1].pred.downto(0) do |minor|
        tags << "rb#{parts[0]}#{minor}"
      end
    end

    tags
  end

  # Generate Darwin platform tags that can actually match via === operator
  def _darwin_platform_tags(tags)
    # Generate Darwin platform tags that can actually match via === operator
    # Only generate exact version and generic tags since platform matching requires exact version matches
    current_version = platform.version.to_i
    cpu_arch = platform.cpu

    # Generate tags for current version only
    formats = _darwin_binary_formats(cpu_arch, current_version)
    formats.each do |format|
      tags << [format, platform.os, current_version].compact.join("-")
    end

    # Generic OS tags without version (broadest compatibility)
    _darwin_binary_formats(cpu_arch, current_version).each do |format|
      tags << [format, platform.os].compact.join("-")
    end
    tags << platform.os
  end

  # Generate binary format combinations for Ruby-supported architectures
  def _darwin_binary_formats(cpu_arch, darwin_version)
    # Generate binary format combinations for Ruby-supported architectures
    # Simplified from Python's _mac_binary_formats for RubyGems needs

    case cpu_arch
    when "x86_64"
      # x86_64 supported from Darwin 8+ (Mac OS X 10.4+)
      if darwin_version >= 8
        ["x86_64", "universal"]
      else
        []
      end
    when "x86"
      # x86 (i386) supported from Darwin 8+ (Mac OS X 10.4+)
      if darwin_version >= 8
        ["x86", "universal"]
      else
        []
      end
    when "arm64"
      # arm64 supported from Darwin 20+ (macOS 11+)
      if darwin_version >= 20
        ["arm64", "universal"]
      else
        []
      end
    when "universal"
      # universal always works for any Darwin version
      ["universal"]
    else
      []
    end
  end

  # Generate compatible tags for this specific environment
  def compatible_tags
    return enum_for(__method__) unless block_given?

    rb_version_range.each do |version|
      normalized_platform_tags.each do |platform_tag|
        yield version, platform_tag
      end
    end
    # yield engine, "any" if engine
    rb_version_range.each do |version|
      yield version, "any"
    end
  end

  def =~(other)
    case other
    when Gem::Platform, Gem::Platform::Wheel
    when Gem::Platform::Specific then other = other.platform
    when String then other = Gem::Platform.new(other)
    else
      return
    end
    platform === other
  end

  def ===(other)
    case other
    when Gem::Platform::Specific then
      # Compare both platform and Ruby environment specifics
      @platform === other.platform &&
        (@ruby_engine.nil? || other.ruby_engine.nil? || @ruby_engine == other.ruby_engine) &&
        (@ruby_engine_version.nil? || other.ruby_engine_version.nil? || @ruby_engine_version == other.ruby_engine_version) &&
        (@ruby_version.nil? || other.ruby_version.nil? || @ruby_version == other.ruby_version) &&
        (@abi_version.nil? || other.abi_version.nil? || @abi_version == other.abi_version)
    when Gem::Platform::Wheel then
      # Use wheel matching logic with this Specific object
      other.send(:match?, self)
    when Gem::Platform then
      # Delegate to underlying platform matching
      @platform === other
    else
      false
    end
  end

  private

  # Get the current Ruby ABI tag for the local environment
  def self.current_ruby_abi_tag
    local.ruby_abi_tag
  end

  ENGINE_MAP = {
    "truffleruby" => :tr,
    "ruby" => :cr,
    "jruby" => :jr,
  }.freeze
  private_constant :ENGINE_MAP

  # Generate ruby ABI tag from specific Ruby environment details
  def self.generate_ruby_abi_tag(ruby_engine, ruby_engine_version, ruby_version, abi_version)
    return nil if !ruby_engine || !ruby_engine_version || !ruby_version

    engine_prefix = ENGINE_MAP[ruby_engine] || ruby_engine
    version_segments = ruby_engine_version.split(".")
    version_part = "#{version_segments[0]}#{version_segments[1]}"

    abi_suffix = extract_abi_suffix(abi_version || ruby_version, ruby_version)

    abi_suffix.empty? ? "#{engine_prefix}#{version_part}" : "#{engine_prefix}#{version_part}_#{abi_suffix}"
  end

  # Extract ABI suffix from version strings with consistent string manipulation
  def self.extract_abi_suffix(abi_version_to_use, ruby_version)
    ruby_version_segments = ruby_version.split(".")
    major_minor_zero = "#{ruby_version_segments[0]}.#{ruby_version_segments[1]}.0"

    suffix = if abi_version_to_use.start_with?(major_minor_zero)
      abi_version_to_use.sub(/^#{Regexp.escape(major_minor_zero)}/, "")
    elsif abi_version_to_use =~ /^#{ruby_version_segments[0]}\.#{ruby_version_segments[1]}\.(\d+)(.*)$/
      patch_version = $1
      extra_suffix = $2

      # For engines like TruffleRuby, if the abi_version starts with the exact ruby_version
      # followed by engine-specific versioning, ignore the engine-specific part entirely
      if ruby_version_segments[2] && patch_version == ruby_version_segments[2] &&
         !extra_suffix.empty? && abi_version_to_use.start_with?(ruby_version + ".")
        ""
      else
        patch_and_suffix = patch_version + extra_suffix
        patch_and_suffix == "0" ? "" : patch_and_suffix
      end
    else
      abi_version_to_use.tr(".", "")
    end

    normalize_abi_suffix(suffix)
  end

  # Normalize ABI suffix by converting separators and removing leading chars
  def self.normalize_abi_suffix(suffix)
    suffix.tr("-", "_").tr(".", "_").sub(/^[._]/, "")
  end

  private_class_method :extract_abi_suffix, :normalize_abi_suffix

  ##
  # Parses a Gem::Platform::Specific string representation back into an object.
  #
  # [+specific_string+] String output from Gem::Platform::Specific#to_s
  #
  # Parses the space-separated key:value format produced by #to_s back into
  # a Specific object with all original attributes restored. This is essential
  # for Bundler lockfile parsing and other serialization needs.
  #
  # The format expected is:
  # "platform_string v:version engine:value engine_version:value ruby_version:value abi_version:value libc_type:value libc_version:value"
  #
  # The version (v:) attribute is mandatory and tracks the format version (currently 1).
  # All other attributes except the platform string are optional and will be nil if not present.
  # The libc_version is expected as dot-separated values (e.g., "2.31") which are parsed to [2, 31].
  #
  #   # Parse a full specification
  #   str = "x86_64-linux v:1 engine:ruby engine_version:3.3.1 ruby_version:3.3.1 abi_version:3.3.0 libc_type:glibc libc_version:2.31"
  #   specific = Gem::Platform::Specific.parse(str)
  #   specific.platform.to_s     #=> "x86_64-linux"
  #   specific.ruby_engine       #=> "ruby"
  #   specific.libc_version      #=> [2, 31]
  #
  #   # Parse minimal specification (platform only)
  #   minimal = Gem::Platform::Specific.parse("x86_64-linux v:1")
  #   minimal.platform.to_s      #=> "x86_64-linux"
  #   minimal.ruby_engine        #=> nil
  #
  # Raises ArgumentError if the string format is invalid or if required
  # platform information cannot be parsed.
  def self.parse(specific_string)
    return nil if specific_string.nil? || specific_string.empty?

    parts = specific_string.strip.split(/\s+/)
    return nil if parts.empty?

    # First part is always the platform string
    platform_str = parts.shift
    platform = Gem::Platform.new(platform_str)

    # Parse remaining key:value pairs and validate version
    attributes = {}
    format_version = nil

    parts.each do |part|
      key, value = part.split(":", 2)
      next unless key && value

      case key
      when "v"
        format_version = value.to_i
      when "engine"
        attributes[:ruby_engine] = value
      when "engine_version"
        attributes[:ruby_engine_version] = value
      when "ruby_version"
        attributes[:ruby_version] = value
      when "abi_version"
        attributes[:abi_version] = value
      when "libc_type"
        attributes[:libc_type] = value
      when "libc_version"
        # Parse dot-separated format like "2.31" back to [2, 31]
        if value.include?(".")
          attributes[:libc_version] = value.split(".").map(&:to_i)
        else
          # Single value or malformed - for manylinux/musllinux compatibility,
          # we need at least 2 elements [major, minor], so set to nil for single values
          attributes[:libc_version] = nil
        end
      end
    end

    # Validate format version - version is mandatory
    case format_version
    when 1
      # Current format version - proceed normally
    when nil
      raise ArgumentError, "missing required version field (v:1)"
    else
      raise ArgumentError, "unsupported specific format version: #{format_version} (supported: 1)"
    end

    new(platform, **attributes)
  rescue StandardError => e
    raise ArgumentError, "invalid specific string format: #{specific_string.inspect} (#{e.message})"
  end

  # Create a Specific instance representing the local Ruby environment
  def self.local(platform = Gem::Platform.local)
    return platform if platform == Gem::Platform::RUBY

    # For Linux platforms, detect libc type and version
    libc_type = nil
    libc_version = nil
    if platform.os == "linux"
      if platform.version&.include?("musl")
        libc_type = "musl"
        libc_version = Gem::Platform::Musllinux.musl_version
      else
        libc_type = "glibc"
        libc_version = Gem::Platform::Manylinux.glibc_version
      end
    end

    new(
      platform,
      ruby_engine: RUBY_ENGINE,
      ruby_engine_version: RUBY_ENGINE_VERSION,
      ruby_version: RUBY_VERSION,
      abi_version: Gem.extension_api_version,
      libc_type: libc_type,
      libc_version: libc_version
    )
  end
end
