module Gem

  ##
  # The cache class is used to hold all the specifications
  # in a provided location ($GEM_PATH) for iteration/searching.
  #
  class Cache
    
    ##
    # Constructs a cache instance with the provided specifications
    #
    # specifications:: [Array] array of Gem::Specification objects
    #
    def initialize(specifications)
      @gems = specifications
    end
    
    
    ##
    # Factory method to construct a cache instance for a provided path
    # 
    # source_dirs:: [default=$GEM_PATH] The path to search for specifications
    # return:: Cache instance
    #
    def self.from_installed_gems(*source_dirs)
      gems = {}
      source_dirs = $GEM_PATH.collect {|dir| File.join(dir, "specifications")} if source_dirs.size==0
      source_dirs.each do |source_dir|
        Dir[File.join(source_dir, "*")].each do |file_name|
          begin
            gem = eval(File.read(file_name))
            gem.loaded_from = file_name
          rescue
            raise "Invalid .gemspec format in: #{source_dir}"
          end
          key = File.basename(file_name).gsub(/\.gemspec/, "")
          gems[key] = gem
        end
      end
      self.new(gems)
    end

    ##
    # Iterate over the specifications in the cache
    #
    # &block:: [yields Gem::Specification]
    #
    def each(&block)
      @gems.each(&block)
    end
    
    ##
    #
    #
    def search(gem_name, version_requirement=Version::Requirement.new(">= 0"))
      unless version_requirement.respond_to? :version
        version_requirement = Version::Requirement.new(version_requirement)
      end
      result = []
      @gems.each do |full_spec_name, spec|
        next unless spec.name == gem_name
        result << spec if version_requirement.satisfied_by?(spec.version)
      end
      result = result.sort
      result
    end
    
  end
  
end
