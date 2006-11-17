#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'socket'
require 'fileutils'
require 'yaml'

require 'rubygems'
require 'rubygems/source_info_cache'
require 'rubygems/source_info_cache_entry'
require 'rubygems/installer'

module Gem
  class DependencyError < Gem::Exception; end
  class RemoteSourceException < Gem::Exception; end
  class GemNotFoundException < Gem::Exception; end
  class RemoteInstallationCancelled < Gem::Exception; end
  class RemoteInstallationSkipped < Gem::Exception; end

  ####################################################################
  # RemoteSourceFetcher handles the details of fetching gems and gem
  # information from a remote source.  
  class RemoteSourceFetcher
    include UserInteraction

    # Initialize a remote fetcher using the source URI (and possible
    # proxy information).  
    # +proxy+
    # * [String]: explicit specification of proxy; overrides any
    #   environment variable setting
    # * nil: respect environment variables (HTTP_PROXY, HTTP_PROXY_USER, HTTP_PROXY_PASS)
    # * <tt>:no_proxy</tt>: ignore environment variables and _don't_
    #   use a proxy
    def initialize(source_uri, proxy)
      @uri = normalize_uri(source_uri)
      @proxy_uri =
      case proxy
      when :no_proxy
        nil
      when nil
        env_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        uri = env_proxy ? URI.parse(env_proxy) : nil
        if uri and uri.user.nil? and uri.password.nil?
          #Probably we have http_proxy_* variables?
          uri.user = escape(ENV['http_proxy_user'] || ENV['HTTP_PROXY_USER'])
          uri.password = escape(ENV['http_proxy_pass'] || ENV['HTTP_PROXY_PASS'])
        end
        uri
      else
        URI.parse(proxy.to_str)
      end
    end

    # The uncompressed +size+ of the source's directory (e.g. source
    # info).
    def size
      @size ||= get_size("/yaml")
    end

    # Fetch the data from the source at the given path.
    def fetch_path(path="")
      read_data(@uri + path)
    end

    # Get the source index from the gem source.  The source index is a
    # directory of the gems available on the source, formatted as a
    # Gem::Cache object.  The cache object allows easy searching for
    # gems by name and version requirement.
    #
    # Notice that the gem specs in the cache are adequate for searches
    # and queries, but may have some information elided (hence
    # "abbreviated").
    def source_index
      say "Bulk updating Gem source index for: #{@uri}"
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
    def escape(str)
      return unless str
      URI.escape(str)
    end

    def unescape(str)
      return unless str
      URI.unescape(str)
    end

    # Normalize the URI by adding "http://" if it is missing.
    def normalize_uri(uri)
      (uri =~ /^(https?|ftp|file):/) ? uri : "http://#{uri}"
    end

    # Connect to the source host/port, using a proxy if needed.
    def connect_to(host, port)
      if @proxy_uri
        Net::HTTP::Proxy(@proxy_uri.host, @proxy_uri.port, unescape(@proxy_uri.user), unescape(@proxy_uri.password)).new(host, port)
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
      return File.size(get_file_uri_path(uri)) if is_file_uri(uri)
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
      begin
    	open_uri_or_path(uri) do |input|
    	  input.read
    	end
      rescue
    	old_uri = uri
    	uri = uri.downcase
    	retry if old_uri != uri
    	raise
      end
    end
    
    # Read the data from the (source based) URI, but if it is a
    # file:// URI, read from the filesystem instead.
    def open_uri_or_path(uri, &block)
      require 'rubygems/open-uri'
      if is_file_uri(uri)
        open(get_file_uri_path(uri), &block)
      else
        connection_options = {"User-Agent" => "RubyGems/#{Gem::RubyGemsVersion}"}
        if @proxy_uri
          http_proxy_url = "#{@proxy_uri.scheme}://#{@proxy_uri.host}:#{@proxy_uri.port}"  
          connection_options[:proxy_http_basic_authentication] = [http_proxy_url, unescape(@proxy_uri.user)||'', unescape(@proxy_uri.password)||'']
        end
        
        open(uri, connection_options, &block)
      end
    end
    
    # Checks if the provided string is a file:// URI.
    def is_file_uri(uri)
      uri =~ %r{\Afile://}
    end
    
    # Given a file:// URI, returns its local path.
    def get_file_uri_path(uri)
      uri.sub(%r{\Afile://}, '')
    end
    
    # Convert the yamlized string spec into a real spec (actually,
    # these are hashes of specs.).
    def convert_spec(yaml_spec)
      YAML.load(reduce_spec(yaml_spec)) or
	fail "Didn't get a valid YAML document"
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

    class << self
      # Sent by the client when it is done with all the sources,
      # allowing any cleanup activity to take place.
      def finish
	# Nothing to do
      end
    end
  end

  ####################################################################
  # CachedFetcher is a decorator that adds local file caching to
  # RemoteSourceFetcher objects.
  class CachedFetcher

    # Create a cached fetcher (based on a RemoteSourceFetcher) for the
    # source at +source_uri+ (through the proxy +proxy+).
    def initialize(source_uri, proxy)
      require 'rubygems/incremental_fetcher'
      @source_uri = source_uri
      rsf = RemoteSourceFetcher.new(source_uri, proxy)
      @fetcher = IncrementalFetcher.new(source_uri, rsf, manager)
    end

    # The uncompressed +size+ of the source's directory (e.g. source
    # info).
    def size
      @fetcher.size
    end

    # Fetch the data from the source at the given path.
    def fetch_path(path="")
      @fetcher.fetch_path(path)
    end

    # Get the source index from the gem source.  The source index is a
    # directory of the gems available on the source, formatted as a
    # Gem::Cache object.  The cache object allows easy searching for
    # gems by name and version requirement.
    #
    # Notice that the gem specs in the cache are adequate for searches
    # and queries, but may have some information elided (hence
    # "abbreviated").
    def source_index
      cache = manager.cache_data[@source_uri]
      if cache && cache.size == @fetcher.size
	cache.source_index
      else
	result = @fetcher.source_index
	manager.cache_data[@source_uri] = SourceInfoCacheEntry.new(result, @fetcher.size)
	manager.update
	result
      end
    end

    # Flush the cache to a local file, if needed.
    def flush
      manager.flush
    end

    private

    # The cache manager for this cached source.
    def manager
      self.class.manager
    end

    # The cache is shared between all caching fetchers, so the cache
    # is put in the class object.
    class << self

      # The Cache manager for all instances of this class.
      def manager
	@manager ||= SourceInfoCache.new
      end

      # Sent by the client when it is done with all the sources,
      # allowing any cleanup activity to take place.
      def finish
	manager.flush
      end
    end
    
  end

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
      unless @sources then
        require 'sources'
        @sources = Gem.sources
      end
      @sources
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
