module Gem
  class LoadError < ::LoadError
    attr_accessor :name, :version_requirement
  end
end

module Kernel

  ##
  # Adds a Ruby Gem to the $LOAD_PATH.  Before a Gem is loaded, its required
  # Gems are loaded (by specified version or highest version).  If the version
  # information is omitted, the highest version Gem of the supplied name is 
  # loaded.  If a Gem is not found that meets the version requirement and/or 
  # a required Gem is not found, a Gem::LoadError is raised. More information on 
  # version requirements can be found in the Gem::Version documentation.
  #
  # As a shortcut, the +gem+ parameter can be a _path_, for example:
  #
  #   require_gem 'rake/packagetask'
  #
  # This is strictly short for
  #
  #   require_gem 'rake'
  #   require 'rake/packagetask' 
  #
  #  You can define the environment variable GEM_SKIP as a way to not
  #  load specified gems.  you might do this to test out changes that haven't 
  #  been intsalled yet.  Example:
  #
  #  GEM_SKIP=libA:libB ruby-I../libA -I../libB ./mycode.rb
  #
  # <i>This is an experimental feature added after versoin 0.7, on 2004-07-13. </i>
  #
  # gem:: [String or Gem::Dependency] The gem name or dependency instance.
  # version_requirement:: [default="> 0.0.0"] The version requirement.
  # return:: [Boolean] true if the Gem is loaded, otherwise false.
  # raises:: [Gem::LoadError] if Gem cannot be found, is listed in GEM_SKIP, or version requirement not met.
  #
  def require_gem(gem, *version_requirements)
    skip_list = (ENV['GEM_SKIP'] || "").split(/:/)
    raise Gem::LoadError, "skipping #{gem}" if skip_list.include? gem
    Gem.activate(gem, true, *version_requirements)
  end
end


##
# Main module to hold all RubyGem classes/modules.
#
module Gem

  class Exception < RuntimeError
  end

  RubyGemsVersion = "0.8.1.2"
  RubyGemsPackageVersion = RubyGemsVersion 

  DIRECTORIES = ['cache', 'doc', 'gems', 'specifications']
  
  @@cache = nil  
  
  class << self
  
    def manage_gems
      require 'rubygems/user_interaction'
      require 'rubygems/builder'
      require 'rubygems/format'
      require 'rubygems/remote_installer'
      require 'rubygems/installer'
      require 'rubygems/validator'
      require 'rubygems/doc_manager'
      require 'rubygems/cmd_manager'
      require 'rubygems/gem_runner'
      require 'rubygems/config_file'
    end
  
    ##
    # Returns an Cache of specifications that are in the Gem.path
    #
    # return:: [Gem::Cache] cache of Gem::Specifications
    #
    def cache
      @@cache ||= Cache.from_installed_gems
      @@cache.refresh!
    end
    
    ##
    # The directory path where Gems are to be installed.
    #
    # return:: [String] The directory path
    #
    def dir
      @gem_home ||= nil
      set_home(ENV['GEM_HOME'] || default_dir) unless @gem_home
      @gem_home
    end
    
    ##
    # List of directory paths to search for Gems.
    #
    # return:: [List<String>] List of directory paths.
    #
    def path
      @gem_path ||= nil
      set_paths(ENV['GEM_PATH']) unless @gem_path
      @gem_path
    end

    # The home directory for the user.
    def user_home
      @user_home ||= find_home
    end
    
    ##
    # Activate a gem (i.e. add it to the Ruby load path).  The gem
    # must satisfy all the specified version constraints.  If
    # +autorequire+ is true, then automatically require the specified
    # autorequire file in the gem spec.
    #
    def activate(gem, autorequire, *version_requirements)
      unless version_requirements.size > 0
        version_requirements = ["> 0.0.0"]
      end
      unless gem.respond_to?(:name) && gem.respond_to?(:version_requirements)
        gem = Gem::Dependency.new(gem, version_requirements)
      end
      
      gem_name_pattern = /^#{gem.name}$/
      matches = Gem.cache.search(gem_name_pattern, gem.version_requirements)
      if matches.size==0
        matches = Gem.cache.search(gem_name_pattern)
        if matches.size==0
          error = Gem::LoadError.new("\nCould not find RubyGem #{gem.name} (#{gem.version_requirements})\n")
          error.name = gem.name
          error.version_requirement = gem.version_requirements
          raise error
        else
          error = Gem::LoadError.new("\nRubyGem version error: #{gem.name}(#{matches.first.version} not #{gem.version_requirements})\n")
          error.name = gem.name
          error.version_requirement = gem.version_requirements
          raise error
        end
      else
        # Get highest matching version
        spec = matches.last
        if spec.loaded?
          result = spec.autorequire ? require(spec.autorequire) : false
          return result || false 
        end
        
        spec.loaded = true
        
        # Load dependent gems first
        spec.dependencies.each do |dep_gem|
          activate(dep_gem, autorequire)
        end
        
        # add bin dir to require_path
        if(spec.bindir) then
          spec.require_paths << spec.bindir
        end

        # Now add the require_paths to the LOAD_PATH
        spec.require_paths.each do |path|
          $:.unshift File.join(spec.full_gem_path, path)
        end
        
        require spec.autorequire if autorequire && spec.autorequire
        return true
      end
    
    end
    
    ##
    # Reset the +dir+ and +path+ values.  The next time +dir+ or +path+
    # is requested, the values will be calculated from scratch.  This is
    # mainly used by the unit tests to provide test isolation.
    #
    def clear_paths
      @gem_home = nil
      @gem_path = nil
      @@cache = nil  
    end
    
    # Use the +home+ and (optional) +paths+ values for +dir+ and +path+.
    # Used mainly by the unit tests to provide environment isolation.
    #
    def use_paths(home, paths=[])
      clear_paths
      set_home(home) if home
      set_paths(paths.join(File::PATH_SEPARATOR)) if paths
    end
    
    # Return a list of all possible load paths for all versions for
    # all gems in the Gem installation.
    #
    def all_load_paths
      result = []
      Gem.path.each do |gemdir|
	each_load_path(all_partials(gemdir)) do |load_path|
	  result << load_path
	end
      end
      result
    end

    # Return a list of all possible load paths for the latest version
    # for all gems in the Gem installation.
    def latest_load_paths
      result = []
      Gem.path.each do |gemdir|
	each_load_path(latest_partials(gemdir)) do |load_path|
	  result << load_path
	end
      end
      result
    end

    def required_location(gemname, libfile, *version_constraints)
      version_constraints = [">0"] if version_constraints.empty?
      matches = Gem.cache.search(gemname, version_constraints)
      return nil if matches.empty?
      spec = matches.last
      spec.require_paths.each do |path|
	result = File.join(spec.full_gem_path, path, libfile)
	return result if File.exists?(result)
      end
    end


    private
    
    # Return all the partial paths in the given +gemdir+.
    def all_partials(gemdir)
      Dir[File.join(gemdir, 'gems/*')]
    end

    # Return only the latest partial paths in the given +gemdir+.
    def latest_partials(gemdir)
      latest = {}
      all_partials(gemdir).each do |gp|
	base = File.basename(gp)
        matches = /(.*)-((\d+\.)*\d+)/.match(base)
	name, version = [matches[1], matches[2]]
	ver = Gem::Version.new(version)
	if latest[name].nil? || ver > latest[name][0]
	  latest[name] = [ver, gp]
	end
      end
      latest.collect { |k,v| v[1] }
    end

    # Expand each partial gem path with each of the required paths
    # specified in the Gem spec.  Each expanded path is yielded.
    def each_load_path(partials) 
      partials.each do |gp|
	base = File.basename(gp)
	specfn = File.join(dir, "specifications", base + ".gemspec")
	if File.exist?(specfn)
	  spec = eval(File.read(specfn))
	  spec.require_paths.each do |rp|
	    yield(File.join(gp, rp))
	  end
	else
	  filename = File.join(gp, 'lib')
	  yield(filename) if File.exist?(filename)
	end
      end
    end

    # Set the Gem home directory (as reported by +dir+).
    def set_home(home)
      @gem_home = home
      ensure_gem_subdirectories(@gem_home)
    end
    
    # Set the Gem search path (as reported by +path+).
    def set_paths(gpaths)
      if gpaths
        @gem_path = gpaths.split(File::PATH_SEPARATOR)
        @gem_path << Gem.dir
      else
        @gem_path = [Gem.dir]
      end      
      @gem_path.uniq!
      @gem_path.each do |gp| ensure_gem_subdirectories(gp) end
    end
    
    # Some comments from the ruby-talk list regarding finding the home
    # directory:
    #
    #   I have HOME, USERPROFILE and HOMEDRIVE + HOMEPATH. Ruby seems
    #   to be depending on HOME in those code samples. I propose that
    #   it should fallback to USERPROFILE and HOMEDRIVE + HOMEPATH (at
    #   least on Win32).
    #
    def find_home
      ['HOME', 'USERPROFILE'].each do |homekey|
	return ENV[homekey] if ENV[homekey]
      end
      if ENV['HOMEDRIVE'] && ENV['HOMEPATH']
	return "#{ENV['HOMEDRIVE']}:#{ENV['HOMEPATH']}"
      end
      begin
	File.expand_path("~")
      rescue Exception => ex
	if File::ALT_SEPARATOR
	  "C:/"
	else
	  "/"
	end
      end
    end
    
    public

    # Default home directory path to be used if an alternate value is
    # not specified in the environment.
    def default_dir
      #rbconfig = Dir.glob("{#{($LOAD_PATH).join(',')}}/rbconfig.rb").first
      #if rbconfig
      #  module_eval File.read(rbconfig) unless const_defined?("Config")
      #else
        require 'rbconfig'
      #end
      File.join(Config::CONFIG['libdir'], 'ruby', 'gems', Config::CONFIG['ruby_version'])
    end

    private 

    # Quietly ensure the named Gem directory contains all the proper
    # subdirectories.  If we can't create a directory due to a
    # permission problem, then we will silently continue.
    def ensure_gem_subdirectories(gemdir)
      DIRECTORIES.each do |filename|
        fn = File.join(gemdir, filename)
        if ! File.exists?(fn) && File.writable?(fn)
          require 'fileutils'
	  FileUtils.mkdir_p(fn)
        end
      end
    end

  end
end

require 'rubygems/source_index'
require 'rubygems/specification'
require 'rubygems/version'
require 'rubygems/loadpath_manager'
