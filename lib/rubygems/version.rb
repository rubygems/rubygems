#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module Gem
  
  ####################################################################
  # The Dependency class holds a Gem name and Version::Requirement
  #
  class Dependency
    attr_accessor :name

    attr_writer :version_requirements

    def <=>(other)
      [@name] <=> [other.name]
    end
    
    ##
    # Constructs the dependency
    #
    # name:: [String] name of the Gem
    # version_requirements:: [String Array] version requirement (e.g. ["> 1.2"])
    #
    def initialize(name, version_requirements)
      @name = name
      @version_requirements = Version::Requirement.new(version_requirements)
      @version_requirement = nil   # Avoid warnings.
    end

    def version_requirements
      normalize if defined? @version_requirement and @version_requirement
      @version_requirements
    end

    def requirement_list
      version_requirements.as_list
    end

    alias requirements_list requirement_list

    def normalize
      ver = @version_requirement.instance_eval { @version }
      @version_requirements = Version::Requirement.new([ver])
      @version_requirement = nil
    end

    def to_s
      "#{name} (#{version_requirements})"
    end

    def ==(other)
      other.kind_of?(self.class) &&
        self.name == other.name &&
        self.version_requirements == other.version_requirements
    end

    def hash
      name.hash + version_requirements.hash
    end
    
  end
  
  ####################################################################
  # The Version class processes string versions into comparable values
  #
  class Version
    include Comparable

    # The originating definition of Requirement is left nested in
    # Version for compatibility.  The full definition is given in
    # Gem::Requirement.
    class Requirement
    end
    
    attr_accessor :version
    
    NUM_RE = /\s*(\d+(\.\d+)*)*\s*/
    
    ##
    # Checks if version string is valid format
    #
    # str:: [String] the version string
    # return:: [Boolean] true if the string format is correct, otherwise false
    #
    def self.correct?(str)
      /^#{NUM_RE}$/.match(str)
    end

    ##
    # Factory method to create a Version object.  Input may be a Version or a
    # String.  Intended to simplify client code.
    #
    #   ver1 = Version.create('1.3.17')   # -> (Version object)
    #   ver2 = Version.create(ver1)       # -> (ver1)
    #   ver3 = Version.create(nil)        # -> nil
    #
    def self.create(input)
      if input.respond_to? :version
        return input
      elsif input.nil?
        return nil
      else
        return Version.new(input)
      end
    end

    ##
    # Constructs a version from the supplied string
    #
    # version:: [String] The version string.  Format is digit.digit...
    #
    def initialize(version)
      raise ArgumentError, 
        "Malformed version number string #{version}" unless Version.correct?(version)
      @version = version
    end
    
    ##
    # Returns the text representation of the version
    #
    # return:: [String] version as string
    #
    def to_s
      @version
    end
    
    ##
    # Convert version to integer array
    #
    # return:: [Array] list of integers
    #
    def to_ints
      @version.scan(/\d+/).map {|s| s.to_i}
    end
    
    ##
    # Compares two versions
    #
    # other:: [Version or .to_ints] other version to compare to
    # return:: [Fixnum] -1, 0, 1
    #
    def <=>(other)
      return 1 unless other
      rnums, vnums = to_ints, other.to_ints
      [rnums.size, vnums.size].max.times {|i|
        rnums[i] ||= 0
        vnums[i] ||= 0
      }
      
      begin
        r,v = rnums.shift, vnums.shift
      end until (r != v || rnums.empty?)

      return r <=> v
    end

    def hash
      to_ints.inject { |hash_code, n| hash_code + n }
    end

    # Return a new version object where the next to the last revision
    # number is one greater. (e.g.  5.3.1 => 5.4)
    def bump
      ints = to_ints
      ints.pop if ints.size > 1
      ints[-1] += 1
      self.class.new(ints.join("."))
    end
    
  end

  # Class Requirement's original definition is nested in Version.
  # Although an probably inappropriate place, current gems specs
  # reference the nested class name explicitly.  To remain compatible
  # with old software loading gemspecs, we leave the original
  # definition in Version, but define an alias Gem::Requirement for
  # use everywhere else.
  Requirement = ::Gem::Version::Requirement

  ##################################################################
  # Requirement version includes a prefaced comparator in addition
  # to a version number.
  #
  # A Requirement object can actually contain multiple, er,
  # requirements, as in (> 1.2, < 2.0).
  #
  class Requirement
    include Comparable
    
    OPS = {
      "="  =>  lambda { |v, r| v == r },
      "!=" =>  lambda { |v, r| v != r },
      ">"  =>  lambda { |v, r| v > r },
      "<"  =>  lambda { |v, r| v < r },
      ">=" =>  lambda { |v, r| v >= r },
      "<=" =>  lambda { |v, r| v <= r },
      "~>" =>  lambda { |v, r| v >= r && v < r.bump }
    }
    
    OP_RE = Regexp.new(OPS.keys.collect{|k| Regexp.quote(k)}.join("|"))
    REQ_RE = /\s*(#{OP_RE})\s*/
    
    ##
    # Factory method to create a Version::Requirement object.  Input may be a
    # Version, a String, or nil.  Intended to simplify client code.
    #
    # If the input is "weird", the default version requirement is returned.
    #
    def self.create(input)
      if input.kind_of?(Requirement)
        return input
      elsif input.kind_of?(Array)
        return self.new(input)
      elsif input.respond_to? :to_str
        return self.new([input.to_str])
      else
        return self.default
      end
    end
    
    ##
    # A default "version requirement" can surely _only_ be '> 0'.
    #
    def self.default
      self.new(['> 0.0.0'])
    end
    
    ##
    # Constructs a version requirement instance
    #
    # str:: [String Array] the version requirement string (e.g. ["> 1.23"])
    #
    def initialize(reqs)
      @requirements = reqs.collect do |rq|
        op, version_string = parse(rq)
        [op, Version.new(version_string)]
      end
      @version = nil   # Avoid warnings.
    end
    
    ##
    # Overrides to check for comparator
    #
    # str:: [String] the version requirement string
    # return:: [Boolean] true if the string format is correct, otherwise false
    #
    # NOTE: Commented out because I don't think it is used.
    #       def correct?(str)
    #         /^#{REQ_RE}#{NUM_RE}$/.match(str)
    #       end
    
    def to_s
      as_list.join(", ")
    end
    
    def as_list
      normalize
      @requirements.collect { |req|
        "#{req[0]} #{req[1]}"
      }
    end
    
    def normalize
      return if not defined? @version or @version.nil?
      @requirements = [parse(@version)]
      @nums = nil
      @version = nil
      @op = nil
    end
    
    ##
    # Is the requirement satifised by +version+.
    #
    # version:: [Gem::Version] the version to compare against
    # return:: [Boolean] true if this requirement is satisfied by
    #          the version, otherwise false 
    #
    def satisfied_by?(version)
      normalize
      @requirements.all? { |op, rv| satisfy?(op, version, rv) }
    end
    
    private
    
    ##
    # Is "version op required_version" satisfied?
    #
    def satisfy?(op, version, required_version)
      OPS[op].call(version, required_version)
    end
    
    ##
    # Parse the version requirement string. Return the operator and
    # version strings.
    #
    def parse(str)
      if md = /^\s*(#{OP_RE})\s*([0-9.]+)\s*$/.match(str)
        [md[1], md[2]]
      elsif md = /^\s*([0-9.]+)\s*$/.match(str)
        ["=", md[1]]
      elsif md = /^\s*(#{OP_RE})\s*$/.match(str)
        [md[1], "0"]
      else
        fail ArgumentError, "Illformed requirement [#{str}]"
      end
    end
    
    def <=>(other)
      to_s <=> other.to_s
    end

    def hash
      to_s.hash
    end
    public :hash
  end
  
end
