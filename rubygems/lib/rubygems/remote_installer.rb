require 'socket'

module Gem
  class DependencyError < Gem::Exception; end
  class RemoteSourceException < Gem::Exception; end
  class GemNotFoundException < Gem::Exception; end
  class RemoteInstallationCancelled < Gem::Exception; end

  class RemoteSourceFetcher
    include UserInteraction

    def initialize(source_uri)
      @uri = source_uri
    end

    def size
      @size ||= get_size
    end

    def source_info
      say "Updating Gem source index for: #{@uri}"
      begin
        require 'zlib'
        yaml_spec = fetch(@uri + "/yaml.Z")
        yaml_spec = Zlib::Inflate.inflate(yaml_spec)
      rescue
        yaml_spec = nil
      end
      begin
	yaml_spec = fetch(@uri + "/yaml") unless yaml_spec
	spec = YAML.load(yaml_spec)
	raise "Didn't get a valid YAML document" if not spec
	spec
      rescue SocketError => e
	raise RemoteSourceException.new("Error fetching remote gem cache: #{e.to_s}")
      end
    end

    def fetch_size(uri)
      require 'net/http'
      require 'uri'
      u = URI.parse(uri)
      http = Net::HTTP.new(u.host, u.port)
      path = (u.path == "") ? "/" : u.path
      resp = http.head(path)
      resp['content-length'].to_i
    end
    
    private

    def get_size
      require 'yaml'
      begin
        yaml_spec_size = fetch_size(@uri + "/yaml.Z")
      rescue
        yaml_spec_size = nil
      end
      yaml_spec_size = fetch_size(@uri + "/yaml") unless yaml_spec_size
      yaml_spec_size
    end

    def fetch(uri)
      require 'rubygems/open-uri'
      open(uri, "User-Agent" => "RubyGems/#{Gem::RubyGemsVersion}", :proxy => @http_proxy) do |input|
        input.read
      end
    end

  end

  class RemoteInstaller
    include UserInteraction

    # <tt>http_proxy</tt>:: * [String]: explicit specification of
    # proxy; overrides any environment variable setting * nil: respect
    # environment variables * <tt>:no_proxy</tt>: ignore environment
    # variables and _don't_ use a proxy
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
      @fetcher_class = RemoteSourceFetcher
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
      caches = source_info(install_dir)
      spec, source = find_gem_to_install(gem_name, version_requirement, caches)
      dependencies = find_dependencies_not_installed(spec.dependencies)
      installed_gems << install_dependencies(dependencies, force, install_dir)
      cache_dir = File.join(install_dir, "cache")
      destination_file = File.join(cache_dir, spec.full_name + ".gem")
      download_gem(destination_file, source, spec)
      installer = new_installer(destination_file)
      installed_gems.unshift installer.install(force, install_dir, install_stub)
      installed_gems.flatten
    end

    # Search Gem repository for a gem by specifying all of part of
    # the Gem's name   
    def search(pattern_to_match)
      results = []
      caches = source_info(Gem.dir)
      caches.each do |cache|
        results << cache[1].search(pattern_to_match)
      end
      results
    end

    # Return a list of the sources that we can download gems from
    def sources
      unless @sources
	require_gem("sources")
	@sources = Gem.sources
      end
      @sources
    end
    
    # Given a list of sources, return a hash of interesting
    # information from those sources, where the key is the source and
    # the value that interesting information.
    def source_info(install_dir)
      source_caches_file = File.join(install_dir, "source_caches")
      if File.exist?(source_caches_file)
	file_data = File.read(source_caches_file)
	# TODO: YAMLing large files can be lengthy.  Can the source
	# cache contain an abreviated gem spec? 
        caches = YAML.load(file_data) || {}
      else
        caches = {}
      end
      updated = false
      sources.each do |source|
	rsf = @fetcher_class.new(source)
	if caches.has_key?(source)
	  if caches[source]["size"] != rsf.size
	    caches[source]["size"] = rsf.size
	    caches[source]["cache"] = rsf.source_info
	    updated = true
	  end
	else
	  caches[source] = {
	    "size" => rsf.size,
	    "cache" => rsf.source_info
	  }
	  updated = true
	end
      end
      if updated && File.writable?(install_dir)
        File.open(source_caches_file, "wb") do |file|
          file.print caches.to_yaml
        end
      end
      result = {}
      caches.each do |source, data|
        result[source] = data["cache"]
      end
      result
    end
    
    def fetch_source(source)
      rsf = @fetcher_class.new(source)
      rsf.source_info
    end

    def find_gem_to_install(gem_name, version_requirement, caches)
      max_version = Version.new("0.0.0")
      specs_n_sources = []
      caches.each do |source, cache|
        cache.each do |name, spec|
          if (/#{gem_name}/i === name && version_requirement.satisfied_by?(spec.version)) then
            specs_n_sources << [spec, source]
          end
        end
      end
      if specs_n_sources.size == 0
        raise GemNotFoundException.new("Could not find #{gem_name} (#{version_requirement}) in the repository")
      end
      # bad code: specs_n_sources.sort! { |a, b| a[0].version <=> b[0].version }.reverse! 
      specs_n_sources = specs_n_sources.sort_by { |x| x[0].version }.reverse
      if specs_n_sources.reject { |item| item[0].platform.nil? || item[0].platform==Platform::RUBY }.size == 0
        # only non-binary gems...return latest
        return specs_n_sources.first
      end
      list = specs_n_sources.collect {|item| "#{item[0].name} #{item[0].version} (#{item[0].platform.to_s})" }
      list << "Cancel installation"
      string, index = choose_from_list("Select which gem to install for your platform (#{RUBY_PLATFORM})", list)
      raise RemoteInstallationCancelled.new("Installation of #{gem_name} cancelled.") if index == (list.size - 1)
      specs_n_sources[index]
      #raise GemNotFoundException.new("Could not find #{gem_name} (#{version_requirement}) in the repository") unless max_version > Version.new("0.0.0")
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

    # Install all the given dependencies.  Returns an array of
    # Gem::Specification objects, one for each dependency installed.
    # 
    # TODO: For now, we recursively install, but this is not the right
    # way to do things (e.g.  if a package fails to download, we
    # shouldn't install anything).
    def install_dependencies(dependencies, force, install_dir)
      installed_gems = []
      dependencies.each do |dependency|
        if ask_yes_no("Install required dependency #{dependency.name}?", true) then
          remote_installer =  RemoteInstaller.new(
            if @http_proxy == false
              :no_proxy
            elsif @http_proxy == true
            else
              @http_proxy
            end
          )

          installed_gems << remote_installer.install(dependency.name, dependency.version_requirements, force, install_dir)
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
      File.open(destination_file, 'wb') do |out|
        out.write(body)
      end
    end
    
    def new_installer(gem)
      return Installer.new(gem)
    end
  end

end
