#!/usr/bin/env ruby
# -*- ruby -*-

#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'rbconfig'

module Gem
  class LoadError < ::LoadError
    attr_accessor :name, :version_requirement
  end
end

module Kernel

  # Adds a Ruby Gem to the $LOAD_PATH.  Before a Gem is loaded, its
  # required Gems are loaded.  If the version information is omitted,
  # the highest version Gem of the supplied name is loaded.  If a Gem
  # is not found that meets the version requirement and/or a required
  # Gem is not found, a Gem::LoadError is raised. More information on
  # version requirements can be found in the Gem::Version
  # documentation.
  #
  # The +gem+ directive should be executed *before* any require
  # statements (otherwise rubygems might select a conflicting library
  # version).
  #
  # You can define the environment variable GEM_SKIP as a way to not
  # load specified gems.  you might do this to test out changes that
  # haven't been intsalled yet.  Example:
  #
  #   GEM_SKIP=libA:libB ruby-I../libA -I../libB ./mycode.rb
  #
  # gem:: [String or Gem::Dependency] The gem name or dependency
  #       instance.
  #
  # version_requirement:: [default=">= 0.0.0"] The version
  #                       requirement.
  #
  # return:: [Boolean] true if the Gem is loaded, otherwise false.
  #
  # raises:: [Gem::LoadError] if Gem cannot be found, is listed in
  #          GEM_SKIP, or version requirement not met. 
  #
  def gem(gem_name, *version_requirements)
    active_gem_with_options(gem_name, version_requirements)
  end
  
  # Same as the +gem+ command, but will also require a file if the gem
  # provides an auto-required file name.
  #
  # DEPRECATED!  Use +gem+ instead.
  #
  def require_gem(gem_name, *version_requirements)
    active_gem_with_options(gem_name,
      version_requirements, :auto_require=>true)
  end

  def active_gem_with_options(gem_name, version_requirements, options={})
    skip_list = (ENV['GEM_SKIP'] || "").split(/:/)
    raise Gem::LoadError, "skipping #{gem_name}" if skip_list.include? gem_name
    Gem.activate(gem_name, options[:auto_require], *version_requirements)
  end
  private :active_gem_with_options
end


# Main module to hold all RubyGem classes/modules.
#
module Gem
  require 'rubygems/rubygems_version.rb'

  class Exception < RuntimeError
  end

  class OperationNotSupportedError < Gem::Exception
  end

  RubyGemsPackageVersion = RubyGemsVersion 

  DIRECTORIES = ['cache', 'doc', 'gems', 'specifications']
  
  @@source_index = nil  
  
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
  
    # Returns an Cache of specifications that are in the Gem.path
    #
    # return:: [Gem::SourceIndex] Index of installed Gem::Specifications
    #
    def source_index
      @@source_index ||= SourceIndex.from_installed_gems
    end

    # Provide an alias for the old name.
    alias cache source_index
    
    # The directory path where Gems are to be installed.
    #
    # return:: [String] The directory path
    #
    def dir
      @gem_home ||= nil
      set_home(ENV['GEM_HOME'] || default_dir) unless @gem_home
      @gem_home
    end
    
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

    # Return the path to standard location of the users .gemrc file.
    def config_file
      File.join(Gem.user_home, '.gemrc')
    end

    # The standard configuration object for gems.
    def configuration
      @configuration ||= {}
    end

    # Use the given configuration object (which implements the
    # ConfigFile protocol) as the standard configuration object.
    def configuration=(config)
      @configuration = config
    end

    # Return the path the the data directory specified by the gem
    # name.  If the package is not available as a gem, return nil.
    def datadir(gem_name)
      return nil if @loaded_specs.nil?
      spec = @loaded_specs[gem_name]
      return nil if spec.nil?
      File.join(spec.full_gem_path, 'data', gem_name)
    end

    # Return the Ruby command to use to execute the Ruby interpreter.
    def ruby
      "ruby"
    end

    # Activate a gem (i.e. add it to the Ruby load path).  The gem
    # must satisfy all the specified version constraints.  If
    # +autorequire+ is true, then automatically require the specified
    # autorequire file in the gem spec.
    #
    # Returns true if the gem is loaded by this call, false if it is
    # already loaded, or an exception otherwise.
    #
    def activate(gem, autorequire, *version_requirements)
      @loaded_specs ||= Hash.new
      unless version_requirements.size > 0
        version_requirements = [">= 0.0.0"]
      end
      unless gem.respond_to?(:name) && gem.respond_to?(:version_requirements)
        gem = Gem::Dependency.new(gem, version_requirements)
      end

      matches = Gem.source_index.find_name(gem.name, gem.version_requirements)
      report_activate_error(gem) if matches.empty?

      if @loaded_specs[gem.name]
	# This gem is already loaded.  If the currently loaded gem is
	# not in the list of candidate gems, then we have a version
	# conflict.
	existing_spec = @loaded_specs[gem.name]
	if ! matches.any? { |spec| spec.version == existing_spec.version }
	  fail Gem::Exception, "can't activate #{gem}, already activated #{existing_spec.full_name}]"
	end
	return false
      end

      # new load
      spec = matches.last
      if spec.loaded?
	return false unless autorequire
	result = spec.autorequire ? require(spec.autorequire) : false
	return result || false 
      end

      spec.loaded = true
      @loaded_specs[spec.name] = spec
      
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
      
      if autorequire && spec.autorequire then
        Array(spec.autorequire).each do |a_lib|
          require a_lib
        end
      end

      return true
    end
    
    # Report a load error during activation.  The message of load
    # error depends on whether it was a version mismatch or if there
    # are not gems of any version by the requested name.
    def report_activate_error(gem)
      matches = Gem.source_index.find_name(gem.name)
      if matches.size==0
	error = Gem::LoadError.new(
	  "Could not find RubyGem #{gem.name} (#{gem.version_requirements})\n")
      else
	error = Gem::LoadError.new(
	  "RubyGem version error: " +
	  "#{gem.name}(#{matches.first.version} not #{gem.version_requirements})\n")
      end
      error.name = gem.name
      error.version_requirement = gem.version_requirements
      raise error
    end
    private :report_activate_error

    # Reset the +dir+ and +path+ values.  The next time +dir+ or +path+
    # is requested, the values will be calculated from scratch.  This is
    # mainly used by the unit tests to provide test isolation.
    #
    def clear_paths
      @gem_home = nil
      @gem_path = nil
      @@source_index = nil  
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
      matches = Gem.source_index.find_name(gemname, version_constraints)
      return nil if matches.empty?
      spec = matches.last
      spec.require_paths.each do |path|
        result = File.join(spec.full_gem_path, path, libfile)
        return result if File.exists?(result)
      end
      nil
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
      rescue StandardError => ex
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
      ## rbconfig = Dir.glob("{#{($LOAD_PATH).join(',')}}/rbconfig.rb").first
      ## if rbconfig
      ##   module_eval File.read(rbconfig) unless const_defined?("Config")
      ## else
      ##   require 'rbconfig'
      ## end
      #
      # Note on above code: we have an issue if a Config class is
      # already defined and we load 'rbconfig'.  The above code is
      # supposed to work around that but it's been commented out.  In
      # any case, I moved "require 'rbconfig'" to the top of this
      # file, because there was a circular dependency between this
      # method and our custom require.  In any case, rbconfig is a
      # fundamental RubyGems dependency, so it might as well be up the
      # top.  -- Gavin Sinclair, 2004-12-12
      #
      if defined? RUBY_FRAMEWORK_VERSION
        return File.join(File.dirname(Config::CONFIG["sitedir"]), "Gems")
      else
        File.join(Config::CONFIG['libdir'], 'ruby', 'gems', Config::CONFIG['ruby_version'])
      end
    end

    private 

    # Quietly ensure the named Gem directory contains all the proper
    # subdirectories.  If we can't create a directory due to a
    # permission problem, then we will silently continue.
    def ensure_gem_subdirectories(gemdir)
      DIRECTORIES.each do |filename|
        fn = File.join(gemdir, filename)
        unless File.exists?(fn)
          require 'fileutils'
          FileUtils.mkdir_p(fn) rescue nil
        end
      end
    end

  end
end


# Modify the non-gem version of datadir to handle gem package names.

require 'rbconfig/datadir'
module Config
  class << self
    alias gem_original_datadir datadir

    # Return the path to the data directory associated with the named
    # package.  If the package is loaded as a gem, return the gem
    # specific data directory.  Otherwise return a path to the share
    # area as define by "#{Config::CONFIG['datadir']}/#{package_name}".
    def datadir(package_name)
      Gem.datadir(package_name) || Config.gem_original_datadir(package_name)
    end
  end
end


require 'rubygems/source_index'
require 'rubygems/specification'
require 'rubygems/security'
require 'rubygems/version'
#require 'rubygems/loadpath_manager'    # custom_require replaces this
require 'rubygems/custom_require'

