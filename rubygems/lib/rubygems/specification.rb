module Gem

  module Platform
    RUBY = nil
    WIN32 = 'mswin32'
    LINUX_586 = 'i586-linux'
    DARWIN = 'powerpc-darwin'
  end
  
  class Specification
    @@list = []
    
    def self.list
      @@list
    end
    
    attr_accessor :rubygems_version, :name, :platform, :date, :summary, :require_paths # required
    attr_reader :version # required
    
    attr_accessor :autorequire, :author, :email, :homepage, :description, :files
    attr_accessor :rubyforge_project
    
    attr_reader :dependencies, :requirements # lists
    
    attr_writer :loaded
    
    def initialize
      @date = Time.now
      @@list << self
      yield self if block_given?
    end
    
    def rubygems_version
      @rubygems_version = RubyGemsVersion
    end
    
    def dependencies
      @dependencies ||= []
    end
    
    def requirements
      @requirements ||= []
    end
    
    def loaded?
      @loaded
    end
    
    def version=(version)
      unless version.respond_to? :version
        version = Version.new(version)
      end
      @version = version
    end
    
    def require_path=(path)
      @require_paths = [path]
    end
    
    def add_dependency(gem, requirement=nil)
      unless gem.respond_to?(:name) && gem.respond_to?(:version_requirement)
        gem = Dependency.new(gem, requirement)
      end
      dependencies << gem
    end
    
    def full_name
      "#{@name}-#{@version}"
    end
    
    def satisfies_requirement?(dependency)
      return @name==dependency.name && 
        dependency.version_requirement.satisfied_by?(@version)
    end
    
    def to_yaml_properties
      rubygems_version
      result = ['@rubygems_version', '@name', '@version', '@date', '@platform', '@summary', '@require_paths']
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
  end
end
