module Gem
  class DependencyError < Gem::Exception; end
  class RemoteSourceException < Gem::Exception; end
  class GemNotFoundException < Gem::Exception; end

  class RemoteInstaller
    include UserInteraction
    ##
    # <tt>http_proxy</tt>::
    #   * [String]: explicit specification of proxy; overrides any environment variable
    #     setting
    #   * nil: respect environment variables
    #   * <tt>:no_proxy</tt>: ignore environment variables and _don't_ use a proxy
    #
    def initialize(http_proxy=nil)
      # Ensure http_proxy env vars are used if no proxy explicitly supplied.
      @http_proxy =
        case http_proxy
        when :no_proxy
          false
        when nil
          true
        else
          http_proxy.to_str
        end
    end

    ##
    # This method will install package_name onto the local system.  
    # package_name:: [String] Name of the Gem to install
    # version_requirement:: [default = "> 0.0.0"] Gem version requirement to install
    #
    # Returns: an array of Gem::Specification objects, one for each gem installed. 
    #
    def install(package_name, version_requirement = "> 0.0.0", force=false, install_dir=Gem.dir, install_stub=true)
      unless version_requirement.respond_to?(:version)
        version_requirement = Version::Requirement.new(version_requirement)
      end
      installed_gems = []
      sources = get_cache_sources()
      caches = get_caches(sources)
      spec, source = find_latest_valid_package_in_caches(package_name,version_requirement,caches)
      dependencies = find_dependencies_not_installed(spec.dependencies)
      installed_gems << install_dependencies(dependencies)
      cache_dir = File.join(Gem::dir, "cache")
      destination_file = File.join(cache_dir, spec.full_name + ".gem")
      download_gem(destination_file, source, spec)
      installer = new_installer(destination_file)
      installed_gems.unshift installer.install(force, install_dir, install_stub)
      installed_gems.flatten
    end

    ##
    # Search Gem repository for a gem by specifying all of part of
    # the Gem's name   
    def search(pattern_to_match)
      results = []
      caches = get_caches(get_cache_sources)
      caches.each do |cache|
        results << cache[1].search(pattern_to_match)
      end
      results
    end


    ##
    # Return a list of the sources that we can download gems from
    def get_cache_sources
      require_gem("sources")
      Gem.sources
    end

    ##
    # Given a list of sources, return a hash of all the caches from those sources, where the key is the source and the value is the cache.
    def get_caches(sources)
      require 'yaml'

      caches = {}
      sources.each do |source|
        begin
          begin
            require 'zlib'
            yaml_spec = fetch(source + "/yaml.Z")
            yaml_spec = Zlib::Inflate.inflate(yaml_spec)
          rescue
            yaml_spec = nil
          end
          yaml_spec = fetch(source + "/yaml") unless yaml_spec
          spec = YAML.load(yaml_spec)
          raise "Didn't get a valid YAML document" if not spec
          caches[source] = spec
        rescue SocketError => e
          raise RemoteSourceException.new("Error fetching remote gem cache: #{e.to_s}")
        end
      end
      return caches
    end

    def find_latest_valid_package_in_caches(package_name,version_requirement,caches)
      max_version = Version.new("0.0.0")
      package = []
      caches.each do |source, cache|
        cache.each do |name, spec|
          if (/#{package_name}/i === name && 
                spec.version > max_version &&
                version_requirement.satisfied_by?(spec.version)) then
            package = [spec, source]
            max_version = spec.version
          end
        end
      end
      raise GemNotFoundException.new("Could not find #{package_name} (#{version_requirement}) in the repository") unless max_version > Version.new("0.0.0")
      package
    end

    def find_dependencies_not_installed(dependencies)
      to_install = []
      dependencies.each do |dependency|
        begin
          require_gem(dependency.name, *dependency.requirement_list)
        rescue LoadError => e
          to_install.push dependency
        end
      end
      to_install
    end

    # 
    # Install all the given dependencies.  Returns an array of Gem::Specification objects, one
    # for each dependency installed.
    # 
    # TODO: For now, we recursively install, but this is not the right way to do things (e.g.
    # if a package fails to download, we shouldn't install anything).
    def install_dependencies(dependencies)
      installed_gems = []
      dependencies.each do |dependency|
        answer = ask("Install required dependency #{dependency.name}? [Yn] ")
        if(answer =~ /^y/i || answer =~ /^[^a-zA-Z0-9]$/) then
          remote_installer = RemoteInstaller.new
          installed_gems << remote_installer.install(dependency.name, dependency.version_requirement)
        else
          raise DependencyError.new("Required dependency #{dependency.name} not installed")
        end
      end
      installed_gems
    end

    def download_gem(destination_file, source, spec)
      uri = source + "/gems/#{spec.full_name}.gem"
      response = fetch(uri)
      write_gem_to_file(response, destination_file)
    end

    def write_gem_to_file(body, destination_file)
      File.open(destination_file, 'w') do |out|
        out.write(body)
      end
    end

    def fetch( uri_str )
      require 'open-uri'
      open(uri_str, :proxy => @http_proxy) do |input|
        input.read
      end
    end

    def new_installer(gem)
      return Installer.new(gem)
    end
  end

end
