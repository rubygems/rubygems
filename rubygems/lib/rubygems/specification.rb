module Gem
  
  ##
  # Available list of platforms for targeting Gem installations.
  # Platform::RUBY is the default platform (pure Ruby Gem).
  #
  module Platform
    RUBY = 'ruby'
    WIN32 = 'mswin32'
    LINUX_586 = 'i586-linux'
    DARWIN = 'powerpc-darwin'
  end
  
  ##
  # Potentially raised when a specification is validated 
  #
  class InvalidSpecificationException < Gem::Exception; end
  
  ##
  # The Specification class contains the metadata for a Gem.  A
  # .gemspec file consists of the defintion of a Specification object
  # and bootstrap code to build the Gem.
  #
  class Specification
    @@list = []
    @@required_attributes = []
    
    ##
    # A list of Specifcation instances that have been defined in this
    # Ruby instance.
    #
    def self.list
      @@list
    end

    ##
    # define accessors for required attributes
    #
    def self.required_attribute(*symbols)
      @@required_attributes.concat symbols
      attr_accessor(*symbols)
    end
    
    ##
    # These attributes are required
    #
    required_attribute :rubygems_version, :name, :date, :summary, :require_paths, :version
    
    ##
    # These attributes are optional
    #
    attr_accessor :autorequire, :author, :email, :homepage, :description, :files, :docs
    attr_accessor :test_suite_file, :default_executable, :bindir, :platform, :rdoc_options
    attr_accessor :rubyforge_project
    attr_writer :has_rdoc, :executables, :extensions
    attr_reader :required_ruby_version
    
    ##
    # Runtime attributes (not persisted)
    #
    attr_writer :loaded, :loaded_from
    
    ##
    # Constructs instance of a Specification
    #
    def initialize
      @date = Time.now
      @bindir, @default_executable, @test_suite_file, @has_rdoc = nil
      @description, @author, @email, @homepage, @rubyforge_project = nil
      @loaded = false
      @has_rdoc = false
      @test_suite_file = nil
      @required_ruby_version = Gem::Version::Requirement.new("> 0.0.0")
      self.platform = nil
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

    undef :require_paths
    ##
    # return:: [Array] list of require paths as strings
    #
    def require_paths
      @require_paths ||= []
    end

    undef :rdoc_options
    ##
    # return:: [Array] list of rdoc arguments as strings
    #
    def rdoc_options
      @rdoc_options ||= []
    end

    ##
    # return:: [Array] list of extra rdoc files as strings
    #
    def extra_rdoc_files
      @extra_rdoc_files ||= []
    end

    ##
    # Returns executables array
    #
    # return:: [Array] array of Strings
    #
    def executables
      @executables ||= []
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
    # Sets additional files (beyond just ruby source files)  to be
    # included in rdoc generation. 
    # Ruby source files will automatically be added
    # 
    # Adding files to this list will automatically add them to the file list
    # (causing them to be added to the gem)
    def extra_rdoc_files=(extra_rdoc_files)
      @files.concat(extra_rdoc_files)
      @extra_rdoc_files = extra_rdoc_files
    end

    ##
    # Returns the extensions array.  This should contain lists of extconf.rb
    # files for use in source distributions.
    #
    # return:: [Array] array of Strings
    #
    def extensions
      @extensions ||= []
    end

    ##
    # Specify which version(s) of Ruby is required to satisfy this gem.
    # version::String Version requirement with same format used for gem 
    #                  dependencies
    def required_ruby_version=(version)
      @required_ruby_version = Gem::Version::Requirement.new(version)
    end
    
    ##
    # Returns the extension requirements array.  This should contain lists of 
    # library/method pairs that are required for the extensions to built.  This
    # is populated during gem creation.
    #
    # return:: [Array] array of Strings
    #
    def extension_requirements
      @extension_requirements ||= []
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
    # Returns if the Gem source is rdoc documented
    #
    # return:: [Boolean] true if Gem has rdoc documentation
    #
    def has_rdoc?
      @has_rdoc
    end
    
    ##
    # Returns if the Gem has a test suite configured
    #
    # return:: [Boolean] true if Gem has a test suite
    #
    def has_test_suite?
      @test_suite_file != nil
    end
    
    undef :version=
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

    undef :summary=
    ##
    # Sets the summary of the Specification, but normalizes the
    # formatting into one line.
    #
    # Such formatting is useful internally, but is a pain for people
    # writing the text.  Normalizing the text this way allows people
    # to be neat in their specifications.
    #
    # summary:: [String] The summary text
    #
    def summary=(summary)
      @summary = summary.strip.gsub(/(\w-)\n[ \t]*(\w)/, '\1\2').gsub(/\n[ \t]*/, " ")
    end
    
    undef description=
    ##
    # As per #summary=, except operating on the description.
    #
    # summary:: [String] The summary text
    #
    def description=(description)
      @description = description.strip.gsub(/(\w-)\n[ \t]*(\w)/, '\1\2').gsub(/\n[ \t]*/, " ")
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
    # Helper method if their is only one executable to install
    #
    # file_path:: [String] The path to the executable script (relative
    #             to the gem)
    #
    def executable=(file_path)
      @executables = [file_path]
    end

    undef :platform=
    ##
    # Specify the platform that the gem targets.  Defaults to a pure-Ruby gem.
    #
    def platform=(platform=Gem::Platform::RUBY)
      @platform = platform
    end
    
    ##
    # Adds a dependency to this Gem
    #
    # gem:: [String or Gem::Dependency] The Gem name/dependency.
    # requirement:: [default="> 0.0.0"] The version requirement.
    #
    def add_dependency(gem, requirement="> 0.0.0")
      unless gem.respond_to?(:name) && gem.respond_to?(:version_requirements)
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
      if @platform.nil? or @platform == Gem::Platform::RUBY
        "#{@name}-#{@version}"
      else
        "#{@name}-#{@version}-#{@platform}"
      end 
    end
    
    ##
    # The full path to the gem (install path + full name)
    #
    # return:: [String] the full gem path
    #
    def full_gem_path
      File.join(installation_path, "gems", full_name)
    end
    
    ##
    # The root directory that the gem was installed into
    #
    # return:: [String] the installation path
    #
    def installation_path
      (File.dirname(@loaded_from).split(File::SEPARATOR)[0..-2]).join(File::SEPARATOR)
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
    # Compare specs (name then version)
    #
    def <=>(other)
      result = @name<=>other.name
      result = @version<=>other.version if result==0
      result
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
      result << '@required_ruby_version' if @required_ruby_version
      result << '@email' if @email
      result << '@homepage' if @homepage
      result << '@rubyforge_project' if @rubyforge_project
      result << '@has_rdoc' if @has_rdoc
      result << '@test_suite_file' if @test_suite_file
      result << '@default_executable' if default_executable
      result << '@bindir' if bindir
      result << '@requirements' if requirements.size > 0
      result << '@executables' if executables.size > 0
      result << '@dependencies' if dependencies.size > 0
      result << '@extensions' if extensions.size > 0
      result << '@rdoc_options' if rdoc_options.size > 0
      result << '@extra_rdoc_files' if extra_rdoc_files.size > 0
      result << '@extension_requirements' if extension_requirements.size > 0
      result << '@description' if @description
      result
    end

    def to_ruby
      mark_version
      result =  "Gem::Specification.new do |s|\n"
      result << "  s.name = %q{#{name}}\n"
      result << "  s.version = %q{#{version}}\n"
      result << "  s.platform = %q{#{platform}}\n" if @platform
      result << "  s.has_rdoc = #{has_rdoc?}\n" if has_rdoc?
      result << "  s.test_suite_file = %q{#{test_suite_file}}\n" if has_test_suite?
      result << "  s.summary = %q{#{summary}}\n"
      if requirements.size>0
        result << "  s.requirements.concat [" + (requirements.collect {|req| '%q{'+req+'}'}).join(', ') + "]\n"
      end
      dependencies.each do |dep|
        result << "  s.add_dependency(%q{" + dep.name + "}, %q{" + dep.version_requirements.to_s + "})\n"
      end
      result << "  s.files = [" + (files.collect {|f| '"' + f + '"'}).join(', ') + "]\n"
      if require_paths
        result << "  s.require_paths = [" + (require_paths.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      if rdoc_options.size > 0
        result << "  s.rdoc_options = [" + (rdoc_options.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      if extra_rdoc_files.size > 0
        result << "  s.extra_rdoc_files = [" + (extra_rdoc_files.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      if executables.size > 0
        result << "  s.executables = [" + (executables.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      if extensions.size > 0
        result << "  s.extensions = [" + (extensions.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      if extension_requirements.size > 0
        result << "  s.extension_requirements = [" + (extension_requirements.collect {|p| '"' + p + '"'}).join(', ') + "]\n"
      end
      # optional 
      result << "  s.autorequire = %q{#{autorequire}}\n" if autorequire
      result << "  s.author = %q{#{author}}\n" if author
      result << "  s.required_ruby_version = %q{#{required_ruby_version}}\n" if required_ruby_version
      result << "  s.email = %q{#{email}}\n" if email
      result << "  s.homepage = %q{#{homepage}}\n" if homepage
      result << "  s.default_executable = %q{#{default_executable}}\n" if default_executable
      result << "  s.bindir = %q{#{bindir}}\n" if bindir
      result << "  s.rubyforge_project = %q{#{rubyforge_project}}\n" if rubyforge_project
      result << "  s.description = <<-EOS\n#{description}\nEOS\n" if description
      result << "end\n"
      result
    end
    
    ##
    # Checks that the specification contains all required fields, and does a 
    # very basic sanity check.  
    # Raises InvalidSpecificationException if the spec does not 
    # pass the checks..
    #
    def validate
      @@required_attributes.each do |symbol|
        unless(self.send(symbol)) 
          raise InvalidSpecificationException.new("Missing value for attribute #{symbol.to_s}")
        end
      end 
      if(@require_paths.size < 1) then
        raise InvalidSpecificationException.new("Gem spec needs to have at least one require_path")
      end
    end

    ##
    #
    private
    def find_all_satisfiers(dep)
      Gem.cache.each do |name,gem|
        if(gem.satisfies_requirement?(dep)) then
          yield gem
        end
      end
    end

    ##
    # return:: [Array] [[dependent_gem, dependency, [list_of_satisfiers]]]
    public
    def dependent_gems
      out = []
      Gem.cache.each do |name,gem|
        gem.dependencies.each do |dep|
          if(self.satisfies_requirement?(dep)) then
            sats = []
            find_all_satisfiers(dep) do |sat|
              sats << sat
            end
            out << [gem, dep, sats]
          end
        end
      end
      out
    end

  end
end
