#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems/user_interaction'

require 'forwardable'
require 'digest/sha2'
require 'time'

module Gem

  # The SourceIndex object indexes all the gems available from a
  # particular source (e.g. a list of gem directories, or a remote
  # source).  A SourceIndex maps a gem full name to a gem
  # specification.
  #
  # NOTE:: The class used to be named Cache, but that became
  #        confusing when cached source fetchers where introduced. The
  #        constant Gem::Cache is an alias for this class to allow old
  #        YAMLized source index objects to load properly.
  #
  class SourceIndex
    extend Forwardable
    include Enumerable

    # Class Methods. -------------------------------------------------
    class << self
      include Gem::UserInteraction
    
      # Factory method to construct a source index instance for a given
      # path.
      #
      # deprecated::
      #   If supplied, from_installed_gems will act just like
      #   +from_gems_in+.  This argument is deprecated and is provided
      #   just for backwards compatibility, and should not generally
      #   be used.
      # 
      # return::
      #   SourceIndex instance
      #
      def from_installed_gems(*deprecated)
        if deprecated.empty?
          from_gems_in(*installed_spec_directories)
        else
          from_gems_in(*deprecated)
        end
      end
      
      # Return a list of directories in the current gem path that
      # contain specifications.
      # 
      # return::
      #   List of directory paths (all ending in "../specifications").
      #
      def installed_spec_directories
	Gem.path.collect { |dir| File.join(dir, "specifications") }
      end

      # Factory method to construct a source index instance for a
      #   given path.
      # 
      # spec_dirs::
      #   List of directories to search for specifications.  Each
      #   directory should have a "specifications" subdirectory
      #   containing the gem specifications.
      #
      # return::
      #   SourceIndex instance
      #
      def from_gems_in(*spec_dirs)
	self.new.load_gems_in(*spec_dirs)
      end
      
      # Load a specification from a file (eval'd Ruby code)
      # 
      # file_name:: [String] The .gemspec file
      # return:: Specification instance or nil if an error occurs
      #
      def load_specification(file_name)
	begin
	  spec_code = File.read(file_name).untaint
	  gemspec = eval(spec_code)
	  if gemspec.is_a?(Gem::Specification)
	    gemspec.loaded_from = file_name
	    return gemspec
	  end
	  alert_warning "File '#{file_name}' does not evaluate to a gem specification"
	rescue SyntaxError => e
	  alert_warning e
	  alert_warning spec_code
	rescue Exception => e
	  alert_warning(e.inspect.to_s + "\n" + spec_code)
	  alert_warning "Invalid .gemspec format in '#{file_name}'"
	end
	return nil
      end
      
    end

    # Instance Methods -----------------------------------------------

    # Constructs a source index instance from the provided
    # specifications
    #
    # specifications::
    #   [Hash] hash of [Gem name, Gem::Specification] pairs
    #
    def initialize(specifications={})
      @gems = specifications
    end
    
    # Reconstruct the source index from the list of source
    # directories.
    def load_gems_in(*spec_dirs)
      @gems.clear
      Dir.glob("{#{spec_dirs.join(',')}}/*.gemspec").each do |file_name|
        gemspec = self.class.load_specification(file_name.untaint)
	add_spec(gemspec) if gemspec
      end
      self
    end

    # Add a gem specification to the source index.
    def add_spec(gem_spec)
      @gems[gem_spec.full_name] = gem_spec
    end

    # Remove a gem specification named +full_name+.
    def remove_spec(full_name)
      @gems.delete(full_name)
    end

    # Iterate over the specifications in the source index.
    #
    # &block:: [yields gem.full_name, Gem::Specification]
    #
    def each(&block)
      @gems.each(&block)
    end

    # The gem specification given a full gem spec name.
    def specification(full_name)
      @gems[full_name]
    end

    # The signature for the source index.  Changes in the signature
    # indicate a change in the index.
    def index_signature
      Digest::SHA256.new(@gems.keys.sort.join(',')).to_s
    end

    # The signature for the given gem specification.
    def gem_signature(gem_full_name)
      Digest::SHA256.new(@gems[gem_full_name].to_yaml).to_s
    end

    def_delegators :@gems, :size, :length

    # Find a gem by an exact match on the short name.
    def find_name(gem_name, version_requirement=Version::Requirement.new(">= 0"))
      search(/^#{gem_name}$/, version_requirement)
    end

    # Search for a gem by short name pattern and optional version
    #
    # gem_name::
    #   [String] a partial for the (short) name of the gem, or
    #   [Regex] a pattern to match against the short name
    # version_requirement::
    #   [String | default=Version::Requirement.new(">= 0")] version to
    #   find
    # return::
    #   [Array] list of Gem::Specification objects in sorted (version)
    #   order.  Empty if not found.
    #
    def search(gem_pattern, version_requirement=Version::Requirement.new(">= 0"))
      #FIXME - remove duplication between this and RemoteInstaller.search
      gem_pattern = /#{ gem_pattern }/i if String === gem_pattern
      version_requirement = Gem::Version::Requirement.create(version_requirement)
      result = []
      @gems.each do |full_spec_name, spec|
        next unless spec.name =~ gem_pattern
        result << spec if version_requirement.satisfied_by?(spec.version)
      end
      result = result.sort
      result
    end

    # Refresh the source index from the local file system.
    #
    # return:: Returns a pointer to itself.
    #
    def refresh!
      load_gems_in(self.class.installed_spec_directories)
    end
    
  end

  # Cache is an alias for SourceIndex to allow older YAMLized source
  # index objects to load properly.
  Cache = SourceIndex

end
