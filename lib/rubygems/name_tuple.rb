# frozen_string_literal: true

##
#
# Represents a gem of name +name+ at +version+ of +platform+. These
# wrap the data returned from the indexes.

class Gem::NameTuple
  def initialize(name, version, platform = Gem::Platform::RUBY, content_address = nil)
    @name = name
    @version = version

    platform &&= platform.to_s
    platform = Gem::Platform::RUBY if !platform || platform.empty?
    @platform = platform
    @content_address = content_address
  end

  attr_reader :name, :version, :platform, :content_address

  ##
  # Turn an array of [name, version, platform] into an array of
  # NameTuple objects.

  def self.from_list(list)
    list.map {|t| new(*t) }
  end

  ##
  # Turn an array of NameTuple objects back into an array of
  # [name, version, platform] tuples.

  def self.to_basic(list)
    list.map(&:to_a)
  end

  ##
  # A null NameTuple, ie name=nil, version=0

  def self.null
    new nil, Gem::Version.new(0), nil
  end

  ##
  # Returns the full name (name-version) of this Gem.  Platform information is
  # included if it is not the default Ruby platform.  This mimics the behavior
  # of Gem::Specification#full_name.

  def full_name
    if @content_address
      "#{@name}-#{@version}-#{@content_address}"
    else
      case @platform
      when nil, "", Gem::Platform::RUBY
        "#{@name}-#{@version}"
      else
        "#{@name}-#{@version}-#{@platform}"
      end
    end
  end

  ##
  # Indicate if this NameTuple matches the current platform.

  def match_platform?
    Gem::Platform.match_gem? @platform, @name
  end

  ##
  # Indicate if this NameTuple is content-addressable (carries a content address).

  def content_addressable?
    !@content_address.nil?
  end

  ##
  # Indicate if this NameTuple is for a prerelease version.
  def prerelease?
    @version.prerelease?
  end

  ##
  # Return the name that the gemspec file would be

  def spec_name
    "#{full_name}.gemspec"
  end

  ##
  # Convert back to the [name, version, platform] tuple

  def to_a
    [@name, @version, @platform]
  end

  alias_method :deconstruct, :to_a

  def deconstruct_keys(keys)
    { name: @name, version: @version, platform: @platform }
  end

  def inspect # :nodoc:
    "#<Gem::NameTuple #{@name}, #{@version}, #{@platform}>"
  end

  alias_method :to_s, :inspect # :nodoc:

  def <=>(other)
    [@name, @version, Gem::Platform.sort_priority(@platform), @content_address.to_s] <=>
      [other.name, other.version, Gem::Platform.sort_priority(other.platform), other.content_address.to_s]
  end

  include Comparable

  ##
  # Compare with +other+. Supports another NameTuple or an Array
  # in the [name, version, platform] format.

  def ==(other)
    case other
    when self.class
      @name == other.name &&
        @version == other.version &&
        @platform == other.platform &&
        @content_address == other.content_address
    when Array
      to_a == other
    else
      false
    end
  end

  alias_method :eql?, :==

  def hash
    [@name, @version, @platform, @content_address].hash
  end
end
