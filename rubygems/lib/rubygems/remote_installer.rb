module Gem

  class RemoteInstaller
    # package_name:: [String] Name of the Gem to install
    # version_requirement:: [default = "> 0.0.0"] Gem version requirement to install
    #
    def initialize(package_name, version_requirement = "> 0.0.0")
      @package_name = package_name
      @version_requirement = Version::Requirement.new(version_requirement)
    end

    ##
    # This method will install @package_name onto the local system.  It does this by:
    # 1. Connect to all the sources and download the yaml caches (TODO: this will eventually be a separate operation
    # 2. Find the latest version of @package_name that satisfies the specified version requirements
    # 3. Find all the dependencies for the desired gem
    # 4. Construct a new RemoteInstaller for all the dependencies that are not installed and install the dependencies
    # 5. Download the necessary file from the source to the gem cache dir
    # 6. Construct an Installer and install the gem
    # TODO: We should be able to download through a proxy
    # TODO: Should we be able to follow redirection?
    def install
      sources = get_cache_sources()
      caches = get_caches(sources)
      spec, source = find_latest_valid_package_in_caches(caches)
      dependencies = find_dependencies_not_installed(spec.dependencies)
      install_dependencies(dependencies)
      cache_dir = File.join(Gem::dir, "cache")
      destination_file = File.join(cache_dir, spec.full_name + ".gem")
      download_gem(destination_file, source, spec)
      installer = new_installer(destination_file)
      installer.install()
      return nil
    end

    ##
    # Return a list of the sources that we can download gems from
    def get_cache_sources
      # TODO
      return ["http://www.chadfowler.com:8808"]
    end

    ##
    # Given a list of sources, return a hash of all the caches from those sources, where the key is the source and the value is the cache.
    def get_caches(sources)
      require 'yaml'
      caches = {}
      sources.each do |source|
        response = fetch(source + "/yaml")
        spec = YAML.load(response.body)
        raise "Didn't get a valid YAML document" if not spec
        caches[source] = spec
      end
      return caches
    end

    def find_latest_valid_package_in_caches(caches)
      max_version = Version.new("0.0.0")
      package = []
      caches.each do |source, cache|
        cache.each do |name, spec|
          if (/#{@package_name}/ === name && 
                spec.version > max_version &&
                @version_requirement.satisfied_by?(spec.version)) then
            package = [spec, source]
            max_version = spec.version
          end
        end
      end
      raise "Could not find #{@package_name} #{@version_requirement.version}" unless max_version > Version.new("0.0.0")
      package
    end

    def find_dependencies_not_installed(dependencies)
      to_install = []
      dependencies.each do |dependency|
        begin
          require_gem(dependency.name, dependency.version_requirement.version)
        rescue LoadError => e
          to_install.push dependency
        end
      end
      to_install
    end

    # TODO: For now, we recursively install, but this is not the right way to do things (e.g. if a package fails to download, we shouldn't install anything).
    def install_dependencies(dependencies)
      dependencies.each do |dependency|
        remote_installer = RemoteInstaller.new(
            dependency.name,
            dependency.version_requirement)
        remote_installer.install
      end
    end

    def download_gem(destination_file, source, spec)
      # TODO
      uri = source + "/gems/#{spec.full_name}.gem"
      response = fetch(uri)
      write_gem_to_file(response.body, destination_file)
    end

    ##
    # Returns the class to use for downloading files via http.  This method exists sole so that it can be overridden in the derived class in a unit test to return a mock http class.  Note that we could override the fetch method in the derived class instead, but then we wouldn't be able to test it.
    def http_class
      require 'net/http'
      return Net::HTTP
    end

    def write_gem_to_file(body, destination_file)
      File.open(destination_file, 'w') do |out|
        out.write(body)
      end
    end

    def fetch( uri_str, limit = 10 )
      require 'uri'
      require 'net/http'

      # You should choose better exception. 
      raise ArgumentError, 'http redirect too deep' if limit == 0

      response = http_class().get_response(URI.parse(uri_str))
      case response
      when Net::HTTPSuccess     then response
      when Net::HTTPRedirection then fetch(response['location'], limit - 1)
      else
        response.error!
      end
    end

    def new_installer(gem)
      return Installer.new(gem)
    end
  end

end
