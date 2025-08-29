# frozen_string_literal: true

require_relative "deprecate"

##
# Available list of platforms for targeting Gem installations.
#
# See `gem help platform` for information on platform matching.

class Gem::Platform
  require_relative "platform/elffile"
  require_relative "platform/manylinux"
  require_relative "platform/musllinux"
  require_relative "platform/wheel"
  require_relative "platform/specific"

  @local = nil

  attr_accessor :cpu, :os, :version

  def self.local(refresh: false)
    return @local if @local && !refresh
    @local = begin
      arch = Gem.target_rbconfig["arch"]
      arch = "#{arch}_60" if /mswin(?:32|64)$/.match?(arch)
      new(arch)
    end
  end

  def self.match(platform)
    match_platforms?(platform, Gem.platforms)
  end

  class << self
    extend Gem::Deprecate
    rubygems_deprecate :match, "Gem::Platform.match_spec? or match_gem?"
  end

  def self.match_platforms?(platform, platforms)
    platform = Gem::Platform.new(platform) unless platform.is_a?(Gem::Platform)
    platforms.any? do |local_platform|
      platform.nil? ||
        local_platform == platform ||
        (local_platform != Gem::Platform::RUBY && platform =~ local_platform)
    end
  end
  private_class_method :match_platforms?

  def self.match_spec?(spec)
    match_gem?(spec.platform, spec.name)
  end

  if RUBY_ENGINE == "truffleruby"
    def self.match_gem?(platform, gem_name)
      raise "Not a string: #{gem_name.inspect}" unless String === gem_name

      if REUSE_AS_BINARY_ON_TRUFFLERUBY.include?(gem_name)
        match_platforms?(platform, [Gem::Platform::RUBY, Gem::Platform::Specific.local])
      else
        match_platforms?(platform, Gem.platforms.map {|pl| Specific.local(pl) })
      end
    end
  else
    def self.match_gem?(platform, gem_name)
      match_platforms?(platform, Gem.platforms.map {|pl| Specific.local(pl) })
    end
  end

  def self.sort_priority(platform)
    case platform
    when Gem::Platform::RUBY then -1
    when Gem::Platform::Wheel then 2 # Higher priority than traditional platforms
    else 1
    end
  end

  def self.installable?(spec)
    if spec.respond_to? :installable_platform?
      spec.installable_platform?
    else
      match_spec? spec
    end
  end

  def self.new(arch) # :nodoc:
    case arch
    when Gem::Platform::CURRENT then
      Gem::Platform.local
    when Gem::Platform::RUBY, nil, "" then
      Gem::Platform::RUBY
    when /^whl-/ then
      Gem::Platform::Wheel.new(arch)
    when Wheel then
      Wheel.new(arch)
    when Specific then
      Specific.new(arch)
    when / v:\d+/
      Gem::Platform::Specific.parse(arch)
    else
      super
    end
  end

  def initialize(arch)
    case arch
    when String then
    when Array then
      raise "Array #{arch.inspect} is not a valid platform" unless arch.size <= 3
      @cpu, @os, @version = arch
      return
    when Gem::Platform
      @cpu = arch.cpu
      @os = arch.os
      @version = arch.version
      return
    else
      raise ArgumentError, "invalid argument #{arch.inspect}"
    end

    cpu, os = arch.sub(/-+$/, "").split("-", 2)

    @cpu = if cpu&.match?(/i\d86/)
      "x86"
    elsif cpu == "dotnet"
      os = "dotnet-#{os}"
      nil
    else
      cpu
    end

    if os.nil?
      @cpu = nil
      os = cpu
    end # legacy jruby

    @os, @version = case os
                    when /aix-?(\d+)?/ then                ["aix",     $1]
                    when /cygwin/ then                     ["cygwin",  nil]
                    when /darwin-?(\d+)?/ then             ["darwin",  $1]
                    when "macruby" then                    ["macruby", nil]
                    when /^macruby-?(\d+(?:\.\d+)*)?/ then ["macruby", $1]
                    when /freebsd-?(\d+)?/ then            ["freebsd", $1]
                    when "java", "jruby" then              ["java",    nil]
                    when /^java-?(\d+(?:\.\d+)*)?/ then    ["java",    $1]
                    when /^dalvik-?(\d+)?$/ then           ["dalvik",  $1]
                    when "dotnet" then                     ["dotnet",  nil]
                    when /^dotnet-?(\d+(?:\.\d+)*)?/ then  ["dotnet",  $1]
                    when /linux-?(\w+)?/ then              ["linux",   $1]
                    when /mingw32/ then                    ["mingw32", nil]
                    when /mingw-?(\w+)?/ then              ["mingw",   $1]
                    when /(mswin\d+)(?:[_-](\d+))?/ then
                      os = $1
                      version = $2
                      @cpu = "x86" if @cpu.nil? && os.end_with?("32")
                      [os, version]
                    when /netbsdelf/ then                  ["netbsdelf", nil]
                    when /openbsd-?(\d+\.\d+)?/ then       ["openbsd",   $1]
                    when /solaris-?(\d+\.\d+)?/ then       ["solaris",   $1]
                    when /wasi/ then                       ["wasi",      nil]
                    # test
                    when /^(\w+_platform)-?(\d+)?/ then    [$1,          $2]
                    else ["unknown", nil]
    end
  end

  def to_a
    [@cpu, @os, @version]
  end

  def to_s
    to_a.compact.join(@cpu.nil? ? "" : "-")
  end

  ##
  # Is +other+ equal to this platform?  Two platforms are equal if they have
  # the same CPU, OS and version.

  def ==(other)
    self.class === other && to_a == other.to_a
  end

  alias_method :eql?, :==

  def hash # :nodoc:
    to_a.hash
  end

  ##
  # Does +other+ match this platform?  Two platforms match if they have the
  # same CPU, or either has a CPU of 'universal', they have the same OS, and
  # they have the same version, or either one has no version
  #
  # Additionally, the platform will match if the local CPU is 'arm' and the
  # other CPU starts with "armv" (for generic 32-bit ARM family support).
  #
  # Of note, this method is not commutative. Indeed the OS 'linux' has a
  # special case: the version is the libc name, yet while "no version" stands
  # as a wildcard for a binary gem platform (as for other OSes), for the
  # runtime platform "no version" stands for 'gnu'. To be able to distinguish
  # these, the method receiver is the gem platform, while the argument is
  # the runtime platform.
  #
  #--
  # NOTE: Until it can be removed, changes to this method must also be reflected in `bundler/lib/bundler/rubygems_ext.rb`

  def ===(other)
    return nil unless Gem::Platform === other

    # universal-mingw32 matches x64-mingw-ucrt
    return true if (@cpu == "universal" || other.cpu == "universal") &&
                   @os.start_with?("mingw") && other.os.start_with?("mingw")

    # cpu
    ([nil,"universal"].include?(@cpu) || [nil, "universal"].include?(other.cpu) || @cpu == other.cpu ||
    (@cpu == "arm" && other.cpu.start_with?("armv"))) &&

      # os
      @os == other.os &&

      # version
      (
        (@os != "linux" && (@version.nil? || other.version.nil?)) ||
        (@os == "linux" && (normalized_linux_version == other.normalized_linux_version || ["musl#{@version}", "musleabi#{@version}", "musleabihf#{@version}"].include?(other.version))) ||
        @version == other.version
      )
  end

  #--
  # NOTE: Until it can be removed, changes to this method must also be reflected in `bundler/lib/bundler/rubygems_ext.rb`

  def normalized_linux_version
    return nil unless @version

    without_gnu_nor_abi_modifiers = @version.sub(/\Agnu/, "").sub(/eabi(hf)?\Z/, "")
    return nil if without_gnu_nor_abi_modifiers.empty?

    without_gnu_nor_abi_modifiers
  end

  ##
  # Does +other+ match this platform?  If +other+ is a String it will be
  # converted to a Gem::Platform first.  See #=== for matching rules.

  def =~(other)
    case other
    when Gem::Platform, Gem::Platform::Wheel
    when Gem::Platform::Specific then other = other.platform
    when String then other = Gem::Platform.new(other)
    else
      return nil
    end

    self === other
  end

  ##
  # A pure-Ruby gem that may use Gem::Specification#extensions to build
  # binary files.

  RUBY = "ruby"

  ##
  # A platform-specific gem that is built for the packaging Ruby's platform.
  # This will be replaced with Gem::Platform::local.

  CURRENT = "current"

  JAVA  = Gem::Platform.new("java") # :nodoc:
  MSWIN = Gem::Platform.new("mswin32") # :nodoc:
  MSWIN64 = Gem::Platform.new("mswin64") # :nodoc:
  MINGW = Gem::Platform.new("x86-mingw32") # :nodoc:
  X64_MINGW_LEGACY = Gem::Platform.new("x64-mingw32") # :nodoc:
  X64_MINGW = Gem::Platform.new("x64-mingw-ucrt") # :nodoc:
  UNIVERSAL_MINGW = Gem::Platform.new("universal-mingw") # :nodoc:
  WINDOWS = [MSWIN, MSWIN64, UNIVERSAL_MINGW].freeze # :nodoc:
  X64_LINUX = Gem::Platform.new("x86_64-linux") # :nodoc:
  X64_LINUX_MUSL = Gem::Platform.new("x86_64-linux-musl") # :nodoc:

  GENERICS = [JAVA, *WINDOWS].freeze # :nodoc:
  private_constant :GENERICS

  GENERIC_CACHE = GENERICS.each_with_object({}) {|g, h| h[g] = g } # :nodoc:
  private_constant :GENERIC_CACHE

  class << self
    ##
    # Returns the generic platform for the given platform.

    def generic(platform)
      case platform
      when NilClass, Gem::Platform::RUBY
        return Gem::Platform::RUBY
      when Gem::Platform::Wheel
        return platform
      when Gem::Platform
      else
        raise ArgumentError, "invalid argument #{platform.inspect}"
      end

      GENERIC_CACHE[platform] ||= begin
        found = GENERICS.find do |match|
          platform === match
        end
        found || Gem::Platform::RUBY
      end
    end

    ##
    # Returns the platform specificity match for the given spec platform and user platform.

    def platform_specificity_match(spec_platform, user_platform)
      return -1 if spec_platform == user_platform
      return 1_000_000 if spec_platform.nil? || spec_platform == Gem::Platform::RUBY || user_platform == Gem::Platform::RUBY

      # Handle Specific user platforms
      if user_platform.is_a?(Gem::Platform::Specific)
        case spec_platform
        when Gem::Platform::Wheel
          # Use each_possible_match to find the best match for wheels
          # Return negative values to indicate better matches than traditional platforms
          index = user_platform.each_possible_match.to_a.index do |abi_tag, platform_tag|
            # Check if the wheel matches this generated tag pair
            spec_platform.ruby_abi_tag.split(".").include?(abi_tag) && spec_platform.platform_tags.split(".").include?(platform_tag)
          end
          return(if index == 0
                   -10
                 elsif index
                   index
                 else
                   1_000_000
                 end)
        when Gem::Platform
          # For traditional platforms with Specific user platforms, use original scoring
          user_platform = user_platform.platform
          return -1 if spec_platform == user_platform # Better than non-matching wheels but worse than matching wheels
        else
          raise ArgumentError, "spec_platform must be Gem::Platform or Gem::Platform::Wheel, given #{spec_platform.inspect}"
        end
      end

      # Handle traditional Platform user platforms
      case user_platform
      when Gem::Platform
        # For wheel spec platforms with traditional user platforms, create a Specific user platform
        if spec_platform.is_a?(Gem::Platform::Wheel)
          specific_user = Gem::Platform::Specific.local(user_platform)
          return platform_specificity_match(spec_platform, specific_user)
        end
      when Gem::Platform::Specific
        # TODO: also match on ruby ABI tags!
        user_platform = user_platform.platform
        return -1 if spec_platform == user_platform
      else
        raise ArgumentError, "user_platform must be Gem::Platform or Gem::Platform::Specific, given #{user_platform.inspect}"
      end

      os_match(spec_platform, user_platform) +
        cpu_match(spec_platform, user_platform) * 10 +
        version_match(spec_platform, user_platform) * 100
    end

    ##
    # Sorts and filters the best platform match for the given matching specs and platform.

    def sort_and_filter_best_platform_match(matching, user_platform)
      return matching if matching.one?

      exact = matching.select {|spec| spec.platform == user_platform }
      return exact if exact.any?

      sorted_matching = sort_best_platform_match(matching, user_platform)
      exemplary_spec = sorted_matching.first

      sorted_matching.take_while {|spec| same_specificity?(user_platform, spec, exemplary_spec) && same_deps?(spec, exemplary_spec) }
    end

    ##
    # Sorts the best platform match for the given matching specs and platform.

    def sort_best_platform_match(matching, user_platform)
      matching.sort_by.with_index do |spec, i|
        [
          platform_specificity_match(spec.platform, user_platform),
          i, # for stable sort
        ]
      end
    end

    private

    def same_specificity?(user_platform, spec, exemplary_spec)
      platform_specificity_match(spec.platform, user_platform) == platform_specificity_match(exemplary_spec.platform, user_platform)
    end

    def same_deps?(spec, exemplary_spec)
      spec.required_ruby_version == exemplary_spec.required_ruby_version &&
        spec.required_rubygems_version == exemplary_spec.required_rubygems_version &&
        spec.dependencies.sort == exemplary_spec.dependencies.sort
    end

    def os_match(spec_platform, user_platform)
      if spec_platform.os == user_platform.os
        0
      else
        1
      end
    end

    def cpu_match(spec_platform, user_platform)
      if spec_platform.cpu == user_platform.cpu
        0
      elsif spec_platform.cpu == "arm" && user_platform.cpu.to_s.start_with?("arm")
        0
      elsif spec_platform.cpu.nil? || spec_platform.cpu == "universal"
        1
      else
        2
      end
    end

    def version_match(spec_platform, user_platform)
      if spec_platform.version == user_platform.version
        0
      elsif spec_platform.version.nil?
        1
      else
        2
      end
    end
  end
end
