module Gem

  ##
  # The cache class is used to hold all the specifications in a
  # provided location (Gem.path) for iteration/searching.
  #
  class Cache
    
    ##
    # Constructs a cache instance with the provided specifications
    #
    # specifications:: [Hash] hash of [Gem name, Gem::Specification] pairs
    #
    def initialize(specifications)
      @gems = specifications
    end
    
    
    ##
    # Factory method to construct a cache instance for a provided path
    # 
    # source_dirs:: [default=Gem.path] The path to search for specifications
    # return:: Cache instance
    #
    def self.from_installed_gems(*source_dirs)
      gems = {}
      source_dirs = Gem.path.collect {|dir| File.join(dir, "specifications")} if source_dirs.empty?
      source_dirs.each do |source_dir|
        Dir[File.join(source_dir, "*gemspec")].each do |file_name|
          begin
            spec_code = File.read(file_name)
            gemspec = eval spec_code
            unless gemspec.is_a? Gem::Specification
              raise Exception, "File '#{file_name}' does not evaluate to a gem specification"
            end
            gemspec.loaded_from = file_name
          rescue Exception => e
            STDERR.puts(e.inspect.to_s + "\n" + spec_code)
            raise "Invalid .gemspec format in '#{file_name}'"
          rescue SyntaxError => e
            STDERR.puts e
            STDERR.puts spec_code
            next
          end
          key = File.basename(file_name).gsub(/\.gemspec/, "")
          gems[key] = gemspec
        end
      end
      self.new(gems)
    end

    ##
    # Iterate over the specifications in the cache
    #
    # &block:: [yields gem_name, Gem::Specification]
    #
    def each(&block)
      @gems.each(&block)
    end

    ##
    # Search for a gem by name and optional version
    #
    # gem_name:: [String] the name of the gem
    # version_requirement:: [String | default=Version::Requirement.new(">= 0")] version to find
    #
    # return:: [Array] list of Gem::Specification objects in sorted (version) order.  empty if not found
    #
    def search(gem_name, version_requirement=Version::Requirement.new(">= 0"))
      #FIXME - remove duplication between this and RemoteInstaller.search
      gem_name = /#{ gem_name }/i if String === gem_name
      version_requirement = version_requirement.to_requirement
      result = []
      @gems.each do |full_spec_name, spec|
        next unless spec.name =~ gem_name
        result << spec if version_requirement.satisfied_by?(spec.version)
      end
      result = result.sort
      result
    end

    ##
    # Refresh the cache.  
    #
    # return:: Returns a pointer to itself.
    #
    def refresh!
      newcache = self.class.from_installed_gems 
      newcache.each do |full_spec_name, spec|
        @gems[full_spec_name] ||= spec
      end
      self
    end
    
  end
  
end
