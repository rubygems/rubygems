require 'rubygems/user_interaction'
module Gem

  ##
  # The cache class is used to hold all the specifications in a
  # provided location (Gem.path) for iteration/searching.
  #
  class Cache
    class << self
      include Gem::UserInteraction
    end
    
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
      Dir.glob("{#{source_dirs.join(',')}}/*.gemspec").each do |file_name|
        gemspec = load_specification(file_name)
        gems[gemspec.full_name] = gemspec if gemspec
      end
      self.new(gems)
    end
    
    ##
    # Load a specification from a file (eval'd Ruby code)
    # 
    # file_name:: [String] The .gemspec file
    # return:: Specification instance or nil if an error occurs
    #
    def self.load_specification(file_name)
      begin
        spec_code = File.read(file_name)
        gemspec = eval(spec_code)
        if gemspec.is_a?(Gem::Specification)
          gemspec.loaded_from = file_name
          return gemspec
        end
        alert_warning "File '#{file_name}' does not evaluate to a gem specification"
      rescue Exception => e
        alert_warning(e.inspect.to_s + "\n" + spec_code)
        alert_warning "Invalid .gemspec format in '#{file_name}'"
      rescue SyntaxError => e
        alert_warning e
        alert_warning spec_code
      end
      return nil
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
    # gem_name::
    #   [String] the name of the gem
    # version_requirement::
    #   [String | default=Version::Requirement.new(">= 0")] version to find
    # return::
    #   [Array] list of Gem::Specification objects in sorted
    #   (version) order.  empty if not found
    #
    def search(gem_name, version_requirement=Version::Requirement.new(">= 0"))
      #FIXME - remove duplication between this and RemoteInstaller.search
      gem_name = /#{ gem_name }/i if String === gem_name
      version_requirement = Gem::Version::Requirement.create(version_requirement)
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
      spec_dirs = Gem.path.collect {|dir| File.join(dir, "specifications")}
      files = Dir.glob("{#{spec_dirs.join(',')}}/*.gemspec")
      current_loaded_files = @gems.values.collect {|spec| spec.loaded_from}
      (files - current_loaded_files).each do |spec_file|
        gemspec = Gem::Cache.load_specification(spec_file)
        @gems[gemspec.full_name] = gemspec if gemspec
      end
      self
    end
    
  end
  
end
