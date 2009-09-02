##
# The Version class processes string versions into comparable
# values. A version string should normally be a series of numbers
# separated by periods. Each part (digits separated by periods) is
# considered its own number, and these are used for sorting. So for
# instance, 3.10 sorts higher than 3.2 because ten is greater than
# two.
#
# If any part contains letters (currently only a-z are supported) then
# that version is considered prerelease. Versions with a prerelease
# part in the Nth part sort less than versions with N-1 parts. Prerelease
# parts are sorted alphabetically using the normal Ruby string sorting
# rules.
#
# Prereleases sort between real releases (newest to oldest):
#
# 1. 1.0
# 2. 1.0.b
# 3. 1.0.a
# 4. 0.9
#
# == Preventing Version Catastrophe:
#
# From: http://blog.zenspider.com/2008/10/rubygems-howto-preventing-cata.html
#
# Let's say you're depending on the fnord gem version 2.y.z. If you
# specify your dependency as ">= 2.0.0" then, you're good, right? What
# happens if fnord 3.0 comes out and it isn't backwards compatible
# with 2.y.z? Your stuff will break as a result of using ">=". The
# better route is to specify your dependency with a "spermy" version
# specifier. They're a tad confusing, so here is how the dependency
# specifiers work:
#
#   Specification From  ... To (exclusive)
#   ">= 3.0"      3.0   ... &infin;
#   "~> 3.0"      3.0   ... 4.0
#   "~> 3.0.0"    3.0.0 ... 3.1
#   "~> 3.5"      3.5   ... 4.0
#   "~> 3.5.0"    3.5.0 ... 3.6

class Gem::Version
  include Comparable

  VERSION_PATTERN = '[0-9]+(\.[0-9a-z]+)*' # :nodoc:
  ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})*\s*\z/ # :nodoc:

  attr_reader :segments

  ##
  # A string representation of this Version.

  attr_reader :version
  alias to_s version

  ##
  # True if the +version+ string matches RubyGems' requirements.

  def self.correct? version
    version.to_s =~ ANCHORED_VERSION_PATTERN
  end

  ##
  # Factory method to create a Version object. Input may be a Version
  # or a String. Intended to simplify client code.
  #
  #   ver1 = Version.create('1.3.17')   # -> (Version object)
  #   ver2 = Version.create(ver1)       # -> (ver1)
  #   ver3 = Version.create(nil)        # -> nil

  def self.create input
    if input.respond_to? :version then
      input
    elsif input.nil? then
      nil
    else
      new input
    end
  end

  ##
  # Constructs a Version from the +version+ string.  A version string is a
  # series of digits or ASCII letters separated by dots.

  def initialize version
    raise ArgumentError, "Malformed version number string #{version}" unless
      self.class.correct?(version)

    @version = version.to_s
    @version.strip!

    @segments = @version.scan(/[0-9a-z]+/i).map do |s|
      /^\d+$/ =~ s ? s.to_i : s
    end
  end

  ##
  # Return a new version object where the next to the last revision
  # number is one greater (e.g., 5.3.1 => 5.4).
  #
  # Pre-release (alpha) parts, e.g, 5.3.1.b2 => 5.4, are ignored.

  def bump
    segments = self.segments.dup
    segments.pop while segments.any? { |s| String === s }
    segments.pop if segments.size > 1

    segments[-1] = segments[-1].succ
    self.class.new segments.join(".")
  end

  ##
  # A Version is only eql? to another version if it's specified to the
  # same precision. Version "1.0" is not the same as version "1".

  def eql? other
    self.class === other and segments == other.segments
  end

  def hash # :nodoc:
    segments.hash
  end

  def inspect # :nodoc:
    "#<#{self.class} #{version.inspect}>"
  end

  ##
  # Dump only the raw version string, not the complete object. It's a
  # string for backwards (RubyGems 1.3.5 and earlier) compatibility.

  def marshal_dump
    [version]
  end

  ##
  # Load custom marshal format. It's a string for backwards (RubyGems
  # 1.3.5 and earlier) compatibility.

  def marshal_load array
    initialize array[0]
  end

  ##
  # A version is considered a prerelease if it contains a letter.

  def prerelease?
    @prerelease ||= segments.any? { |s| String === s }
  end

  def pretty_print q # :nodoc:
    q.text "Gem::Version.new(#{version.inspect})"
  end

  ##
  # The release for this version (e.g. 1.2.0.a -> 1.2.0).
  # Non-prerelease versions return themselves.

  def release
    return self unless prerelease?

    segments = self.segments.dup
    segments.pop while segments.any? { |s| String === s }
    self.class.new segments.join('.')
  end

  ##
  # A recommended version for use with a ~> Requirement.

  def spermy_recommendation
    segments = self.segments.dup

    segments.pop    while segments.any? { |s| String === s }
    segments.pop    while segments.size > 2
    segments.push 0 while segments.size < 2

    "~> #{segments.join(".")}"
  end

  ##
  # Compares this version with +other+ returning -1, 0, or 1 if the other
  # version is larger, the same, or smaller than this one.

  def <=> other
    return   1 unless other # HACK: comparable with nil? why?
    return nil unless self.class === other

    # This method's motto: Object allocation is for suckers. This
    # method is used often enough that avoiding extra object creation
    # makes a real difference.

    lhsize = segments.size
    rhsize = other.segments.size
    limit  = (lhsize > rhsize ? lhsize : rhsize) - 1

    0.upto(limit) do |i|
      lhs, rhs = segments[i] || 0, other.segments[i] || 0

      return  -1         if String  === lhs && Numeric === rhs
      return   1         if Numeric === lhs && String  === rhs
      return lhs <=> rhs if lhs != rhs
    end

    return 0
  end
end
