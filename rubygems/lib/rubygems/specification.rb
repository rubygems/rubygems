module Gem
  
  ##
  # Available list of platforms for targeting Gem installations.
  # Platform::RUBY is the default platform (pure Ruby Gem).
  #
  module Platform
    RUBY = nil
    WIN32 = 'mswin32'
    LINUX_586 = 'i586-linux'
    DARWIN = 'powerpc-darwin'
  end
  
  ##
  # The Specification class contains the metadata for a Gem.  A
  # .gemspec file consists of the defintion of a Specification object
  # and bootstrap code to build the Gem.
  #
  class Specification
    @@list = []
    
    ##
    # A list of Specifcation instances that have been defined in this
    # Ruby instance.
    #
    def self.list
      @@list
    end
    
    ##
    # This attributes are required
    #
    attr_accessor :rubygems_version, :name, :platform, :date, :summary, :require_paths
    attr_reader :version
    
    ##
    # These attributes are optional
    #
    attr_accessor :autorequire, :author, :email, :homepage, :description, :files
    attr_accessor :rubyforge_project
    
    attr_reader :dependencies, :requirements
    
    ##
    # Runtime attributes (not persisted)
    #
    attr_writer :loaded
    
    ##
    # Constructs instance of a Specification
    #
    def initialize
      @date = Time.now
      @@list << self
      yield self if block_given?
    end
    
    ##
    # Marks the rubygems_version to the Gem::RubyGemsVersion
    #
    def mark_version
      @rubygems_version = RubyGemsVersion
    end
    
    ##
    # Returns dependency array
    #
    # return:: [Array] array of Gem::Dependency instances
    #
    def dependencies
      @dependencies ||= []
    end
    
    ##
    # Returns the requirements arrays.  Requirements are text requirements
    # that are output to the screen if a Gem could not be loaded for some
    # reason.
    #
    # return:: [Array] array of Strings
    #
    def requirements
      @requirements ||= []
    end
    
    ##
    # Returns if the Gem represented by the specification is loaded.
    #
    # return:: [Boolean] true if Gem is loaded
    #
    def loaded?
      @loaded
    end
    
    ##
    # Sets the version of the Specification
    #
    # version:: [String or Gem::Version] The version
    #
    def version=(version)
      unless version.respond_to? :version
        version = Version.new(version)
      end
      @version = version
    end
    
    ##
    # Helper method if the require path is singular
    #
    # path:: [String] The require path.
    #
    def require_path=(path)
      @require_paths = [path]
    end
    
    ##
    # Adds a dependency to this Gem
    #
    # gem:: [String or Gem::Dependency] The Gem name/dependency.
    # requirement:: [default="> 0.0.0"] The version requirement.
    #
    def add_dependency(gem, requirement="> 0.0.0")
      unless gem.respond_to?(:name) && gem.respond_to?(:version_requirement)
        gem = Dependency.new(gem, requirement)
      end
      dependencies << gem
    end
    
    ##
    # The full name (name-version) of this Gem
    #
    # return:: [String] The full name name-version
    #
    def full_name
      "#{@name}-#{@version}"
    end
    
    ##
    # Checks if this Specification meets the requirement of the supplied
    # dependency
    # 
    # dependency:: [Gem::Dependency] the dependency to check
    # return:: [Boolean] true if dependency is met, otherwise false
    #
    def satisfies_requirement?(dependency)
      return @name==dependency.name && 
        dependency.version_requirement.satisfied_by?(@version)
    end
    
    ##
    # Order the YAML properties
    #
    # return:: [Array] list of string attributes for YAML
    #
    def to_yaml_properties
      mark_version
      result = ['@rubygems_version', '@name', '@version', '@date', '@platform', '@summary', '@require_paths', '@files']
      result << '@autorequire' if @autorequire
      result << '@author' if @author
      result << '@email' if @email
      result << '@homepage' if @homepage
      result << '@rubyforge_project' if @rubyforge_project
      result << '@requirements' if requirements.size > 0
      result << '@dependencies' if dependencies.size > 0
      result << '@description' if @description
      result
    end
    
    def to_ruby
      mark_version
      result =  "Gem::Specification.new do |s|\n"
      result << "s.name = '#{name}'\n"
      result << "s.version = '#{version}'\n"
      result << "s.platform = '#{platform}'\n" if @platform
      result << "s.summary = '#{summary}'\n"
      if requirements.size>0
        result << "s.requirements.concat [" + (requirements.collect {|req| '"'+req+'"'}).join(', ') + "]\n"
      end
      dependencies.each do |dep|
        result << "s.add_dependency('" + dep.name + "', '" + dep.version_requirement.to_s + "')\n"
      end
      result << "s.files = [" + (files.collect {|f| '"' + f + '"'}).join(', ') + "]\n"
      if require_paths
        result << "s.require_paths = [" + (require_paths.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      # optional 
      result << "s.autorequire = '#{autorequire}'\n" if autorequire
      result << "s.author = '#{author}'\n" if author
      result << "s.email = '#{email}'\n" if email
      result << "s.homepage = '#{homepage}'\n" if homepage
      result << "s.rubyforge_project = '#{rubyforge_project}'\n" if rubyforge_project
      result << "s.description = <<-EOS\n#{description}\nEOS\n" if description
      result << "end\n"
      result
    end
  end
end
