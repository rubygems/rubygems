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
    
    matches = Gem.cache.search(gem.name, gem.version_requirement)
    if matches.size==0
      matches = Gem.cache.search(gem.name)
      if matches.size==0
        raise LoadError.new("\nCould not find RubyGem #{gem.name}\n")
      else
        raise LoadError.new("\nRubyGem version error: #{gem.name}(#{matches.first.version} not #{gem.version_requirement.version})\n")
      end
    else
      # Get highest matching version
      spec = matches.last
      return false if spec.loaded?
      
      spec.loaded = true
      
      # Load dependent gems first
      spec.dependencies.each do |dep_gem|
        require_gem(dep_gem)
      end
      
      # Now add the require_paths to the LOAD_PATH
      spec.require_paths.each do |path|
        $:.unshift File.join(spec.full_gem_path, path)
      end
      
      require spec.autorequire if spec.autorequire
      
      return true
    end
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
    @@cache.refresh!
  end
  
  ##
  # Return the directory that Gems are installed in
  #
  # return:: [String] The directory path
  #
  def self.dir
    return $GEM_PATH.first if defined?($GEM_PATH)
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

$GEM_PATH=[Gem.dir]
if ENV['RUBY_GEMS']
  env_paths = ENV['RUBY_GEMS'].split(File::PATH_SEPARATOR)
  env_paths.each do |path|
    puts "WARNING: RUBY_GEMS path #{path} does not exist" unless File.exist?(path)
  end
  $GEM_PATH = env_paths.concat $GEM_PATH
end

require 'rubygems/cache'
require 'rubygems/builder'
require 'rubygems/installer'
require 'rubygems/specification'
require 'rubygems/remote_installer'
require 'rubygems/version'
require 'rubygems/validator'
require 'rubygems/format'
require 'rubygems/doc_manager'
