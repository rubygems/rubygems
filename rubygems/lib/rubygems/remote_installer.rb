require 'socket'

module Gem
  class DependencyError < Gem::Exception; end
  class RemoteSourceException < Gem::Exception; end
  class GemNotFoundException < Gem::Exception; end
  class RemoteInstallationCancelled < Gem::Exception; end

  # RemoteSourceFetcher handles the details of fetching gemms and gem
  # information from a remote source.  
  class RemoteSourceFetcher
    include UserInteraction

    # Initialize a remote fetcher using the source URI (and possible
    # proxy information).
    def initialize(source_uri, proxy)
      @uri = source_uri
      @http_proxy = proxy
      if @http_proxy == true
	@http_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
      end
    end

    # Return the (uncompressed) size of the source info.
    def size
      @size ||= get_size("/yaml")
    end

    # Fetch the data from the source at the given path.
    def fetch_path(path="")
      read_data(@uri + path)
    end

    # Get the source info stored on the source.  Source info is a hash
    # map of gem long names to gem specs.  Notice that the gem specs
    # returned by this method are adequate for searches and queries,
    # but may have some information elided.
    def source_info
      say "Updating Gem source index for: #{@uri}"
      begin
        require 'zlib'
        yaml_spec = fetch_path("/yaml.Z")
        yaml_spec = Zlib::Inflate.inflate(yaml_spec)
      rescue
        yaml_spec = nil
      end
      begin
	yaml_spec = fetch_path("/yaml") unless yaml_spec
	convert_spec(yaml_spec)
      rescue SocketError => e
	raise RemoteSourceException.new("Error fetching remote gem cache: #{e.to_s}")
      end
    end

    private

    # Connect to the source host/port, using a proxy if needed.
    def connect_to(host, port)
      if @http_proxy
	proxy_uri = URI.parse(@http_proxy)
	Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port).new(host, port)
      else
	Net::HTTP.new(host, port)
      end
    end
    
    # Get the size of the (non-compressed) data from the source at the
    # given path.
    def get_size(path)
      read_size(@uri + path)
    end

    # Read the size of the (source based) URI using an HTTP HEAD
    # command.
    def read_size(uri)
      require 'net/http'
      require 'uri'
      u = URI.parse(uri)
      http = connect_to(u.host, u.port)
      path = (u.path == "") ? "/" : u.path
      resp = http.head(path)
      fail RemoteSourceException, "HTTP Response #{resp.code}" if resp.code !~ /^2/
      resp['content-length'].to_i
    end

    # Read the data from the (source based) URI.
    def read_data(uri)
      require 'rubygems/open-uri'
      open(uri,
	"User-Agent" => "RubyGems/#{Gem::RubyGemsVersion}",
	:proxy => @http_proxy
	) do |input|
        input.read
      end
    end

    # Convert the yamlized string spec into a real spec (actually,
    # these are hashes of specs.).
    def convert_spec(yaml_spec)
      YAML.load(reduce_spec(yaml_spec)) or
	raise "Didn't get a valid YAML document"
    end

    # This reduces the source spec in size so that YAML bugs with
    # large data sets will be dodged.  Obviously this is a workaround,
    # but it allows Gems to continue to work until the YAML bug is
    # fixed.  
    def reduce_spec(yaml_spec)
      result = ""
      state = :copy
      yaml_spec.each do |line|
	if state == :copy && line =~ /^\s+files:\s*$/
	  state = :skip
	  result << line.sub(/$/, " []")
	elsif state == :skip
	  if line !~ /^\s+-/
	    state = :copy
	  end
	end
	result << line if state == :copy
      end
      result
    end

  end

  class RemoteInstaller
    include UserInteraction

    # <tt>http_proxy</tt>::
    # * [String]: explicit specification of proxy; overrides any
    #   environment variable setting
    # * nil: respect environment variables
    # * <tt>:no_proxy</tt>: ignore environment variables and _don't_
    #   use a proxy
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
        caches = YAML.load(file_data) || {}
      else
        caches = {}
      end
      updated = false
      sources.each do |source|
	rsf = @fetcher_class.new(source, @http_proxy)
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
      rsf = @fetcher_class.new(source, @http_proxy)
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
      rsf = @fetcher_class.new(source, @http_proxy)
      path = "/gems/#{spec.full_name}.gem"
      response = rsf.fetch_path(path)
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
