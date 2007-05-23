#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rubygems/user_interaction'
require 'rubygems/remote_fetcher'
require 'rubygems/digest/sha2'

require 'forwardable'
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

    include Gem::UserInteraction

    INCREMENTAL_THRESHHOLD = 50

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
      specs = Dir.glob File.join("{#{spec_dirs.join(',')}}", "*.gemspec")
      specs.each do |file_name|
        gemspec = self.class.load_specification(file_name.untaint)
        add_spec(gemspec) if gemspec
      end
      self
    end

    # Returns a Hash of name => Specification of the latest versions of each
    # gem in this index.
    def latest_specs
      thin = {}

      each do |full_name, spec|
        name = spec.name
        if thin.has_key? name then
          thin[name] = spec if spec.version > thin[name].version
        else
          thin[name] = spec
        end
      end

      thin
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
      Gem::SHA256.new.hexdigest(@gems.keys.sort.join(',')).to_s
    end

    # The signature for the given gem specification.
    def gem_signature(gem_full_name)
      Gem::SHA256.new.hexdigest(@gems[gem_full_name].to_yaml).to_s
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

    # Returns an Array of Gem::Specifications that are not up to date.
    #
    def outdated
      remotes = Gem::SourceInfoCache.search(//)
      outdateds = []
      latest_specs.each do |_, local|
        name = local.name
        remote = remotes.select  { |spec| spec.name == name }.
                         sort_by { |spec| spec.version }.
                         last
        outdateds << name if remote and local.version < remote.version
      end
      outdateds
    end

    def update(source_uri)
      use_incremental = false

      begin
        gem_names = fetch_quick_index source_uri
        remove_extra gem_names
        missing_gems = find_missing gem_names
        use_incremental = missing_gems.size <= INCREMENTAL_THRESHHOLD
      rescue Gem::OperationNotSupportedError => ex
        use_incremental = false
      end

      if use_incremental then
        update_with_missing source_uri, missing_gems
      else
        new_index = fetch_bulk_index source_uri
        @gems.replace new_index.gems
      end

      self
    end
    
    def ==(other) # :nodoc:
      self.class === other and @gems == other.gems 
    end

    protected

    attr_reader :gems

    private

    # Convert the yamlized string spec into a real spec (actually, these are
    # hashes of specs.).
    def convert_specs(yaml_spec)
      YAML.load(reduce_specs(yaml_spec)) or
      raise "Didn't get a valid YAML document"
    end

    def fetcher
      Gem::RemoteFetcher.fetcher
    end

    def fetch_bulk_index(source_uri)
      say "Bulk updating Gem source index for: #{source_uri}"

      begin
        yaml_spec = fetcher.fetch_path source_uri + '/yaml.Z'
        yaml_spec = unzip yaml_spec
      rescue
        begin
          yaml_spec = fetcher.fetch_path source_uri + '/yaml'
        rescue => e
          raise Gem::RemoteSourceException,
                "Error fetching remote gem cache: #{e}"
        end
      end

      convert_specs yaml_spec
    end

    # Get the quick index needed for incremental updates.
    def fetch_quick_index(source_uri)
      zipped_index = fetcher.fetch_path source_uri + '/quick/index.rz'
      unzip(zipped_index).split("\n")
    rescue ::Exception => ex
      raise Gem::OperationNotSupportedError,
            "No quick index found: " + ex.message
    end

    # Make a list of full names for all the missing gemspecs.
    def find_missing(spec_names)
      spec_names.find_all { |full_name|
        specification(full_name).nil?
      }
    end

    # This reduces the source spec in size so that YAML bugs with large data
    # sets will be dodged.  Obviously this is a workaround, but it allows Gems
    # to continue to work until the YAML bug is fixed.  
    def reduce_specs(yaml_spec)
      result = ""
      state = :copy
      yaml_spec.each do |line|
        if state == :copy && line =~ /^\s+files:\s*$/
          state = :skip
          result << line.sub(/$/, " []")
        elsif state == :skip
          if line !~ /^\s+-/
            state = :copy
          end
        end
        result << line if state == :copy
      end
      result
    end

    def remove_extra(spec_names)
      dictionary = spec_names.inject({}) { |h, k| h[k] = true; h }
      each do |name, spec|
        remove_spec name unless dictionary.include? name
      end
    end

    # Unzip the given string.
    def unzip(string)
      require 'zlib'
      Zlib::Inflate.inflate(string)
    end

    # Update the cached source index with the missing names.
    def update_with_missing(source_uri, missing_names)
      progress = ui.progress_reporter(missing_names.size,
        "Need to update #{missing_names.size} gems from #{source_uri}")
      missing_names.each do |spec_name|
        begin
          spec_uri = source_uri + "/quick/#{spec_name}.gemspec.rz"
          zipped_yaml = fetcher.fetch_path spec_uri
          gemspec = YAML.load unzip(zipped_yaml)
          add_spec gemspec
          progress.updated spec_name
        rescue RuntimeError => ex
          ui.say "Failed to download spec for #{spec_name} from #{source_uri}"
        end
      end
      progress.done
      progress.count
    end

  end

  # Cache is an alias for SourceIndex to allow older YAMLized source
  # index objects to load properly.
  Cache = SourceIndex

end

