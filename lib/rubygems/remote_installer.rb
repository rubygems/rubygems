#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'fileutils'
require 'yaml'

require 'rubygems'
require 'rubygems/cached_fetcher'
require 'rubygems/installer'

module Gem
  class DependencyError < Gem::Exception; end
  class GemNotFoundException < Gem::Exception; end
  class RemoteInstallationCancelled < Gem::Exception; end
  class RemoteInstallationSkipped < Gem::Exception; end

  class RemoteInstaller
    include UserInteraction

    # <tt>options[:http_proxy]</tt>::
    # * [String]: explicit specification of proxy; overrides any
    #   environment variable setting
    # * nil: respect environment variables (HTTP_PROXY, HTTP_PROXY_USER, HTTP_PROXY_PASS)
    # * <tt>:no_proxy</tt>: ignore environment variables and _don't_
    #   use a proxy
    #
    def initialize(options={})
      require 'uri'

      # Ensure http_proxy env vars are used if no proxy explicitly supplied.
      @options = options
      @fetcher_class = CachedFetcher
      @sources = nil
    end

    # This method will install package_name onto the local system.  
    #
    # gem_name::
    #   [String] Name of the Gem to install
    #
    # version_requirement::
    #   [default = "> 0.0.0"] Gem version requirement to install
    #
    # Returns::
    #   an array of Gem::Specification objects, one for each gem installed. 
    #
    def install(gem_name, version_requirement = "> 0.0.0", force=false, install_dir=Gem.dir, install_stub=true)
      unless version_requirement.respond_to?(:satisfied_by?)
        version_requirement = Version::Requirement.new(version_requirement)
      end
      installed_gems = []
      caches = source_index_hash
      begin
        spec, source = find_gem_to_install(gem_name, version_requirement, caches)
        dependencies = find_dependencies_not_installed(spec.dependencies)
        installed_gems << install_dependencies(dependencies, force, install_dir)
        cache_dir = File.join(install_dir, "cache")
        destination_file = File.join(cache_dir, spec.full_name + ".gem")
        download_gem(destination_file, source, spec)
        installer = new_installer(destination_file)
        installed_gems.unshift installer.install(force, install_dir, install_stub)
      rescue RemoteInstallationSkipped => e
        puts e.message
      end
      installed_gems.flatten
    end

    # Search Gem repository for a gem by specifying all or part of
    # the Gem's name   
    def search(pattern_to_match)
      results = []
      caches = source_index_hash
      caches.each do |cache|
        results << cache[1].search(pattern_to_match)
      end
      results
    end

    # Return a list of the sources that we can download gems from
    def sources
      return @sources if @sources
      require 'sources'
      @sources = Gem.sources
    end
    
    # Return a hash mapping the available source names to the source
    # index of that source.
    def source_index_hash
      result = {}
      sources.each do |source|
	result[source] = fetch_source(source)
      end
      @fetcher_class.finish
      result
    end
    
    # Return the source info for the given source.  The 
    def fetch_source(source)
      rsf = @fetcher_class.new(source, @options[:http_proxy])
      rsf.source_index
    end

    # Find a gem to be installed by interacting with the user.
    def find_gem_to_install(gem_name, version_requirement, caches)
      specs_n_sources = []

      caches.each do |source, cache|
        cache.each do |name, spec|
          if /^#{gem_name}$/i === spec.name &&
             version_requirement.satisfied_by?(spec.version) then
            specs_n_sources << [spec, source]
          end
        end
      end

      if specs_n_sources.empty? then
        raise GemNotFoundException.new("Could not find #{gem_name} (#{version_requirement}) in the repository")
      end

      specs_n_sources = specs_n_sources.sort_by { |gs,| gs.version }.reverse
      top_3_versions = specs_n_sources.map{|gs| gs.first.version}.uniq[0..3]
      specs_n_sources.reject!{|gs| !top_3_versions.include?(gs.first.version)}

      non_binary_gems = specs_n_sources.reject { |item|
        item[0].platform.nil? || item[0].platform==Platform::RUBY
      }

      # only non-binary gems...return latest
      return specs_n_sources.first if non_binary_gems.empty?

      list = specs_n_sources.collect { |item|
	"#{item[0].name} #{item[0].version} (#{item[0].platform.to_s})"
      }

      list << "Skip this gem"
      list << "Cancel installation"

      string, index = choose_from_list(
	"Select which gem to install for your platform (#{RUBY_PLATFORM})",
	list)

      if index == (list.size - 1) then
        raise RemoteInstallationCancelled, "Installation of #{gem_name} cancelled."
      end

      if index == (list.size - 2) then
        raise RemoteInstallationSkipped, "Installation of #{gem_name} skipped."
      end

      specs_n_sources[index]
    end

    def find_dependencies_not_installed(dependencies)
      to_install = []
      dependencies.each do |dependency|
	srcindex = Gem::SourceIndex.from_installed_gems
	matches = srcindex.find_name(dependency.name, dependency.requirement_list)
	to_install.push dependency if matches.empty?
      end
      to_install
    end

    # Install all the given dependencies.  Returns an array of
    # Gem::Specification objects, one for each dependency installed.
    # 
    # TODO: For now, we recursively install, but this is not the right
    # way to do things (e.g.  if a package fails to download, we
    # shouldn't install anything).
    def install_dependencies(dependencies, force, install_dir)
      return if @options[:ignore_dependencies]
      installed_gems = []
      dependencies.each do |dependency|
        if @options[:include_dependencies] ||
	    ask_yes_no("Install required dependency #{dependency.name}?", true)
          remote_installer =  RemoteInstaller.new(@options)
          installed_gems << remote_installer.install(
	    dependency.name,
	    dependency.version_requirements,
	    force,
	    install_dir)
        else
          raise DependencyError.new("Required dependency #{dependency.name} not installed")
        end
      end
      installed_gems
    end

    def download_gem(destination_file, source, spec)
      rsf = @fetcher_class.new(source, @options[:http_proxy])
      path = "/gems/#{spec.full_name}.gem"
      response = rsf.fetch_path(path)
      write_gem_to_file(response, destination_file)
    end

    def write_gem_to_file(body, destination_file)
      FileUtils.mkdir_p(File.dirname(destination_file)) unless File.exist?(destination_file)
      File.open(destination_file, 'wb') do |out|
        out.write(body)
      end
    end
    
    def new_installer(gem)
      return Installer.new(gem, @options)
    end
  end

end
