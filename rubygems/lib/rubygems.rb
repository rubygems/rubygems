module Kernel
  def require_gem(gem, version_requirement="> 0.0.0")
    unless gem.respond_to?(:name) && gem.respond_to?(:version_requirement)
      gem = Gem::Dependency.new(gem, version_requirement)
    end
    
    error_message = "\nCould not find RubyGem #{gem.name}\n"
    
    Gem.specifications.each do |spec|
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

module Gem
  RubyGemsVersion = "1.0"
  
  @@specification_list = []
  
  def self.specifications
    return @@specification_list if @@specification_list.size > 0
    require 'yaml'
    Dir[File.join("#{Gem.dir}","specifications","*.gemspec")].each do |specfile|
      @@specification_list << YAML.load(File.read(specfile))
    end
    @@specification_list
  end
  
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