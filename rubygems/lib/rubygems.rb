module Kernel

  ##
  # Adds a Ruby Gem to the $LOAD_PATH.  Before a Gem is loaded, its required
  # Gems are loaded (by specified version or highest version).  If the version
  # information is omitted, the highest version Gem of the supplied name is 
  # loaded.  If a Gem is not found that meets the version requirement and/or 
  # a required Gem is not found, a LoadError is raised. More information on 
  # version requirements can be found in the Gem::Version documentation.
  #
  # gem:: [String or Gem::Dependency] The gem name or dependency instance.
  # version_requirement:: [default="> 0.0.0"] The version requirement.
  # return:: [Boolean] true if the Gem is loaded, otherwise false.
  # raises:: [LoadError] if Gem cannot be found or version requirement not met.
  #
  def require_gem(gem, version_requirement="> 0.0.0")
    unless gem.respond_to?(:name) && gem.respond_to?(:version_requirement)
      gem = Gem::Dependency.new(gem, version_requirement)
    end
    
    error_message = "\nCould not find RubyGem #{gem.name}\n"
    
    Gem.cache.each do |full_spec_name, spec|
      next unless spec.name == gem.name
      
      if gem.version_requirement.satisfied_by?(spec.version)
      
        return false if spec.loaded?
        
        spec.loaded = true
        spec.require_paths.each do |path|
          $:.unshift File.join(Gem.dir, spec.full_name, path)
        end
        
        # Load dependent gems first
        spec.dependencies.each do |dep_gem|
          require_gem(dep_gem)
        end
        
        require spec.autorequire if spec.autorequire
        
        return true
      else
        error_message = "\nRubyGem version error: #{gem.name}(#{spec.version} not #{gem.version_requirement.version})\n"
      end
    end

    raise LoadError.new(error_message)
  end
end

##
# Main module to hold all RubyGem classes/modules.
#
module Gem
  RubyGemsVersion = "1.0"
  
  @@cache = nil
  
  ##
  # Returns an Cache of specifications that are in the $GEM_PATH
  #
  # return:: [Gem::Cache] cache of Gem::Specifications
  #
  def self.cache
    @@cache ||= Cache.from_installed_gems
  end
  
  ##
  # Return the directory that Gems are installed in
  #
  # return:: [String] The directory path
  #
  def self.dir
    require 'rbconfig'
    dir = File.join(Config::CONFIG['libdir'], 'ruby', 'gems', Config::CONFIG['ruby_version'])
    unless File.exist?(File.join(dir, 'specifications'))
      require 'fileutils'
      FileUtils.mkdir_p(File.join(dir, 'specifications'))
    end
    unless File.exist?(File.join(dir, 'cache'))
      require 'fileutils'
      FileUtils.mkdir_p(File.join(dir, 'cache'))
    end
    dir
  end
end

require 'rubygems/cache'
require 'rubygems/builder'
require 'rubygems/installer'
require 'rubygems/specification'
require 'rubygems/version'
require 'rubygems/remote_installer'