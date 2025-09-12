# frozen_string_literal: true

##
# Wheel platform matching for Ruby wheel formats.
#
# The Gem::Platform::Wheel class provides wheel-format platform tag parsing
# and matching against Ruby platform specifications. This enables compatibility
# with Python's wheel format conventions while maintaining Ruby-specific
# platform semantics.
#
# Wheel format follows the pattern: whl-{abi_tag}-{platform_tag}
# where tags can be combined with dots (e.g., "whl-rb33.rb32-x86_64_linux.any")
#
# == When to Use Gem::Platform::Wheel
#
# Use Gem::Platform::Wheel when you need:
# - Parsing wheel-format platform strings from gem specifications
# - Cross-language compatibility with Python wheel conventions
# - Multi-platform gem distribution with precise ABI targeting
# - Checking compatibility between wheel specs and Ruby environments
#
# Use Gem::Platform::Specific for:
# - Generating wheel-compatible tags from Ruby environments
# - Ruby-centric platform detection and matching
# - Local environment analysis and tag generation
#
# == Basic Usage
#
#   # Parse wheel format string
#   wheel = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
#   wheel.ruby_abi_tag    #=> "rb33"
#   wheel.platform_tags   #=> "x86_64_linux"
#
#   # Check compatibility with current environment
#   current_platform = Gem::Platform::Specific.local
#   compatible = wheel === current_platform  #=> true/false
#
#   # Multi-tag wheel support
#   multi_wheel = Gem::Platform::Wheel.new("whl-rb33.rb32.any-x86_64_linux.any")
#   multi_wheel.expand
#   #=> [["rb33", "x86_64_linux"], ["rb33", "any"],
#   #    ["rb32", "x86_64_linux"], ["rb32", "any"],
#   #    ["any", "x86_64_linux"], ["any", "any"]]
#
# == Tag Normalization
#
# Platform and ABI tags are automatically normalized:
# - Dots and hyphens become underscores: "x86-64" -> "x86_64"
# - Tags are sorted and deduplicated: "rb32.rb33.rb32" -> "rb32.rb33"
#
#   wheel = Gem::Platform::Wheel.new("whl-rb33-x86-64.darwin")
#   wheel.platform_tags  #=> "darwin.x86_64"
#
# == Compatibility Matching
#
# Wheel compatibility follows these rules:
# 1. "any" tags match everything
# 2. Specific tags must match exactly
# 3. Multi-tag wheels match if ANY tag combination is compatible
#
#   # Universal wheel matches everything
#   universal = Gem::Platform::Wheel.new("whl-any-any")
#   universal === any_platform  #=> true
#
#   # Multi-tag wheel has fallback compatibility
#   fallback = Gem::Platform::Wheel.new("whl-rb33.any-x86_64_linux.any")
#   fallback === old_ruby_env   #=> true (via "any" ABI tag)
#   fallback === different_arch #=> true (via "any" platform tag)
#
# == Error Handling
#
# Invalid wheel format strings raise ArgumentError:
#
#   Gem::Platform::Wheel.new("invalid-format")     #=> ArgumentError
#   Gem::Platform::Wheel.new("whl-INVALID-tag")    #=> ArgumentError
#   Gem::Platform::Wheel.new("whl-rb33")           #=> ArgumentError (missing platform)
#
# == Performance Characteristics
#
# - Tag parsing and normalization happen at initialization
# - Compatibility checks are O(nxm) where n,m are tag counts
# - Memory usage scales with number of tags in wheel specification
# - Thread-safe for read operations after initialization
#
# == Integration with Gem::Platform::Specific
#
# Wheel objects work seamlessly with Specific objects for environment matching:
#
#   specific = Gem::Platform::Specific.local
#   wheel = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
#
#   compatible = wheel === specific
#   # Uses specific.each_possible_match internally for comprehensive checking
#
# This class bridges Python wheel conventions with Ruby's platform system,
# enabling cross-ecosystem compatibility while maintaining Ruby semantics.

class Gem::Platform::Wheel
  attr_reader :ruby_abi_tag, :platform_tags

  ##
  # Normalizes wheel tag sets by converting separators and sorting.
  #
  # [+tags+] Tag string with dot-separated values, or nil/empty
  #
  # Performs normalization by:
  # - Converting dots and hyphens to underscores
  # - Splitting on dots, deduplicating, and sorting
  # - Rejoining with dots for consistent representation
  #
  # Returns "any" for nil or empty input, preserving wheel format conventions.
  #
  #   normalize_tag_set("rb33.rb32.rb33")     #=> "rb32.rb33"
  #   normalize_tag_set("x86-64.darwin")      #=> "darwin.x86_64"
  #   normalize_tag_set(nil)                  #=> "any"
  #   normalize_tag_set("")                   #=> "any"
  def self.normalize_tag_set(tags)
    return "any" if tags.nil? || tags.empty?
    tags.split(".").map {|tag| tag.gsub(/[.-]/, "_") }.uniq.sort.join(".")
  end

  ##
  # Creates a new Gem::Platform::Wheel instance.
  #
  # [+wheel_string+] Wheel format string or existing Wheel object
  #
  # Parses wheel format strings following the pattern "whl-{abi_tag}-{platform_tag}".
  # Both abi_tag and platform_tag can contain multiple dot-separated values for
  # compatibility with multiple targets.
  #
  # If passed an existing Wheel object, creates a copy with the same tags.
  #
  # Raises ArgumentError for:
  # - Invalid wheel format (missing "whl-" prefix or wrong part count)
  # - Invalid tag characters (must follow platform naming conventions)
  # - Non-string, non-Wheel arguments
  #
  #   # Basic wheel specification
  #   wheel = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
  #
  #   # Multi-target wheel
  #   wheel = Gem::Platform::Wheel.new("whl-rb33.rb32.any-x86_64_linux.any")
  #
  #   # Copy constructor
  #   copy = Gem::Platform::Wheel.new(existing_wheel)
  def initialize(wheel_string)
    case wheel_string
    when Gem::Platform::Wheel
      @ruby_abi_tag = wheel_string.ruby_abi_tag
      @platform_tags = wheel_string.platform_tags
      return
    when String
    else
      raise ArgumentError
    end

    parts = wheel_string.split("-", 3)
    unless parts.size == 3 && parts[0] == "whl"
      raise ArgumentError, "invalid wheel string format: #{wheel_string.inspect}"
    end

    @ruby_abi_tag = self.class.normalize_tag_set(parts[1])
    @platform_tags = self.class.normalize_tag_set(parts[2])

    validate_tags!
  end

  ##
  # Returns the canonical wheel format string representation.
  #
  # Reconstructs the wheel string from parsed components in the format
  # "whl-{abi_tag}-{platform_tag}". Tags remain normalized as stored.
  #
  #   wheel = Gem::Platform::Wheel.new("whl-rb33.rb32-x86_64_linux.any")
  #   wheel.to_s  #=> "whl-rb32.rb33-any.x86_64_linux"
  def to_s
    to_a.join("-")
  end

  ##
  # Returns the wheel components as an array.
  #
  # Provides access to the wheel's three components in order:
  # [prefix, abi_tag, platform_tag] where prefix is always "whl".
  #
  #   wheel = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
  #   wheel.to_a  #=> ["whl", "rb33", "x86_64_linux"]
  def to_a
    ["whl", @ruby_abi_tag, @platform_tags]
  end

  ##
  # Expands multi-tag wheel into all possible tag combinations.
  #
  # For wheels with dot-separated multiple tags, generates the Cartesian
  # product of all ABI tags and platform tags. This is useful for checking
  # compatibility against all possible combinations the wheel supports.
  #
  # Returns an array of [abi_tag, platform_tag] pairs.
  #
  #   wheel = Gem::Platform::Wheel.new("whl-rb33.any-x86_64_linux.any")
  #   wheel.expand
  #   #=> [["rb33", "x86_64_linux"], ["rb33", "any"],
  #   #    ["any", "x86_64_linux"], ["any", "any"]]
  #
  #   # Single-tag wheels return single combination
  #   simple = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
  #   simple.expand  #=> [["rb33", "x86_64_linux"]]
  def expand
    ruby_abi_tags = @ruby_abi_tag == "any" ? ["any"] : @ruby_abi_tag.split(".")
    platform_tags = @platform_tags == "any" ? ["any"] : @platform_tags.split(".")

    ruby_abi_tags.product(platform_tags)
  end

  ##
  # Tests wheel equality based on tag content.
  #
  # [+other+] Another Wheel object to compare against
  #
  # Two wheels are equal if they have identical normalized ABI and platform tags.
  # The order of tags doesn't matter since normalization sorts them.
  #
  #   wheel1 = Gem::Platform::Wheel.new("whl-rb33.rb32-x86_64_linux")
  #   wheel2 = Gem::Platform::Wheel.new("whl-rb32.rb33-x86_64_linux")
  #   wheel1 == wheel2  #=> true (tags are normalized and sorted)
  #
  #   wheel3 = Gem::Platform::Wheel.new("whl-rb33-arm64_darwin")
  #   wheel1 == wheel3  #=> false
  def ==(other)
    return false unless self.class === other
    to_a == other.to_a
  end

  alias_method :eql?, :==

  ##
  # Generates hash code for use in Hash collections.
  #
  # Hash is computed from the wheel's normalized components, ensuring
  # equal wheels produce the same hash code for proper Hash behavior.
  #
  #   wheel = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
  #   hash = { wheel => "cached_gem" }
  #   hash[wheel]  #=> "cached_gem"
  def hash
    to_a.hash
  end

  ##
  # Pattern matching alias for compatibility checking.
  #
  # [+other+] Platform object, string, or Specific object to check against
  #
  # Provides =~ operator support for pattern-like matching. Delegates to
  # the === operator for actual compatibility logic.
  #
  #   wheel = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
  #   wheel =~ "x86_64-linux"  #=> same as wheel === "x86_64-linux"
  def =~(other)
    case other
    when Gem::Platform, Gem::Platform::Wheel then
    when Gem::Platform::Specific then other = other.platform
    when String then other = Gem::Platform.new(other)
    else
      return
    end
    self === other
  end

  ##
  # Checks wheel compatibility with Ruby platforms and environments.
  #
  # [+other+] Platform, Wheel, Specific object, or string to check against
  #
  # Performs comprehensive compatibility checking based on the type of object:
  #
  # - Gem::Platform::Wheel: Direct wheel-to-wheel equality comparison
  # - Gem::Platform::Specific: Advanced matching using environment tag generation
  # - Gem::Platform: Legacy platform matching with current Ruby ABI
  # - String: Converts to Platform and matches
  #
  # Returns true if this wheel is compatible with the target environment.
  #
  # == Matching Rules
  #
  # 1. "any" tags always match
  # 2. Specific tags must have exact matches
  # 3. Multi-tag wheels match if ANY combination is compatible
  # 4. ABI and platform tags are checked independently
  #
  #   # Universal wheel matches everything
  #   universal = Gem::Platform::Wheel.new("whl-any-any")
  #   universal === anything  #=> true
  #
  #   # Specific wheel requires compatible environment
  #   specific = Gem::Platform::Wheel.new("whl-rb33-x86_64_linux")
  #   specific === Gem::Platform::Specific.local  # true if Ruby 3.3 on x86_64 Linux
  #
  #   # Multi-tag provides fallback compatibility
  #   fallback = Gem::Platform::Wheel.new("whl-rb33.any-x86_64_linux.any")
  #   fallback === old_ruby_platform  # true via "any" ABI tag
  def ===(other)
    case other
    when Gem::Platform::Wheel then
      # Handle wheel-to-wheel comparison
      self == other
    when Gem::Platform::Specific then
      # Use wheel matching logic with the Specific object
      send(:match?, other)
    when Gem::Platform then
      # Use the new tuple-based matching approach
      send(:match?, ruby_abi_tag: Gem::Platform::Specific.current_ruby_abi_tag, platform: other)
    when Gem::Platform::RUBY, nil, ""
      true
    else
      raise ArgumentError, "invalid argument #{other.inspect}"
    end
  end

  private

  def match?(specific = nil, ruby_abi_tag: nil, platform: nil)
    # Handle both new Specific-based API and legacy parameter-based API
    if specific
      raise ArgumentError, "specific must be a Gem::Platform::Specific" unless specific.is_a?(Gem::Platform::Specific)
      raise ArgumentError, "cannot specify both specific and keyword arguments" if ruby_abi_tag || platform

      # Use each_possible_match to check if this wheel matches any of the possible tags
      wheel_abi_tags = @ruby_abi_tag.split(".")
      wheel_platform_tags = @platform_tags.split(".")

      specific.each_possible_match do |abi_tag, platform_tag|
        if wheel_abi_tags.include?(abi_tag) && wheel_platform_tags.include?(platform_tag)
          return true
        end
      end

      return false
    else
      raise ArgumentError, "must provide either specific or both ruby_abi_tag and platform" unless ruby_abi_tag && platform
    end

    # Legacy matching for non-Specific objects
    # Check ruby/ABI compatibility
    return false unless @ruby_abi_tag == "any" || @ruby_abi_tag.split(".").include?(ruby_abi_tag)

    # Check platform compatibility
    platform_tag = Gem::Platform::Wheel.normalize_tag_set(platform.to_s)
    @platform_tags == "any" || @platform_tags.split(".").include?(platform_tag)
  end

  def validate_tags!
    validate_ruby_abi_tag!
    validate_platform_tags!
  end

  def validate_ruby_abi_tag!
    return if @ruby_abi_tag == "any"
    @ruby_abi_tag.split(".").each do |tag|
      unless /^[a-z][a-z0-9_]*$/.match?(tag)
        raise ArgumentError, "invalid ruby/ABI tag: #{tag.inspect}"
      end
    end
  end

  def validate_platform_tags!
    return if @platform_tags == "any"
    @platform_tags.split(".").each do |tag|
      unless /^[a-z0-9_][a-z0-9_-]*$/.match?(tag)
        raise ArgumentError, "invalid platform tag: #{tag.inspect}"
      end
    end
  end
end
