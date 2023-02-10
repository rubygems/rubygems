# frozen_string_literal: true

module Bundler
  # used for Creating Specifications from the Gemcutter Endpoint
  class EndpointSpecification < Gem::Specification
    include MatchRemoteMetadata

    attr_reader :name, :version, :platform, :checksum
    attr_accessor :source, :remote, :dependencies

    def initialize(name, version, platform, spec_fetcher, dependencies, metadata = nil)
      super()
      @name         = name
      @version      = Gem::Version.create version
      @platform     = Gem::Platform.new(platform)
      @spec_fetcher = spec_fetcher
      @dependencies = dependencies.map {|dep, reqs| build_dependency(dep, reqs) }

      @loaded_from          = nil
      @remote_specification = nil

      parse_metadata(metadata)
    end

    def fetch_platform
      @platform
    end

    # needed for standalone, load required_paths from local gemspec
    # after the gem is installed
    def require_paths
      if @remote_specification
        @remote_specification.require_paths
      elsif _local_specification
        _local_specification.require_paths
      else
        super
      end
    end

    # needed for inline
    def load_paths
      # remote specs aren't installed, and can't have load_paths
      if _local_specification
        _local_specification.load_paths
      else
        super
      end
    end

    # needed for binstubs
    def executables
      if @remote_specification
        @remote_specification.executables
      elsif _local_specification
        _local_specification.executables
      else
        super
      end
    end

    # needed for bundle clean
    def bindir
      if @remote_specification
        @remote_specification.bindir
      elsif _local_specification
        _local_specification.bindir
      else
        super
      end
    end

    # needed for post_install_messages during install
    def post_install_message
      if @remote_specification
        @remote_specification.post_install_message
      elsif _local_specification
        _local_specification.post_install_message
      else
        super
      end
    end

    # needed for "with native extensions" during install
    def extensions
      if @remote_specification
        @remote_specification.extensions
      elsif _local_specification
        _local_specification.extensions
      else
        super
      end
    end

    def _local_specification
      return unless @loaded_from && File.exist?(local_specification_path)
      eval(File.read(local_specification_path)).tap do |spec|
        spec.loaded_from = @loaded_from
      end
    end

    def __swap__(spec)
      SharedHelpers.ensure_same_dependencies(self, dependencies, spec.dependencies)
      @remote_specification = spec
    end

    # if we don't get the checksum from the server
    # calculating the checksum from the file on disk still provides some measure of security
    # if it changes from install to install, that is cause for concern
    def to_checksum
      return Bundler::Checksum.new(name, version, platform, "sha256-#{checksum}") if checksum
      return Bundler::Checksum.new(name, version, platform) unless File.exists?(_fetched_gem)

      calculated_checksum = File.open(_fetched_gem) do |f|
        digest = Bundler::SharedHelpers.digest(:SHA256).new
        digest << f.read(16_384) until f.eof?

        hexdigest = digest.hexdigest!
        hexdigest
      end

      Bundler::Checksum.new(name, version, platform, "sha256-#{calculated_checksum}") if calculated_checksum
    end

    private

    def _fetched_gem
      @_fetched_gem ||= begin
        fetcher = gem_remote_fetcher
        fetcher.headers = { "X-Gemfile-Source" => remote.original_uri.to_s } if remote&.original_uri
        fetcher.download(self, remote.uri)
      end
    end

    def gem_remote_fetcher
      require "rubygems/remote_fetcher"
      proxy = Gem.configuration[:http_proxy]
      Gem::RemoteFetcher.new(proxy)
    end

    def _remote_specification
      @_remote_specification ||= @spec_fetcher.fetch_spec([@name, @version, @platform])
    end

    def local_specification_path
      "#{base_dir}/specifications/#{full_name}.gemspec"
    end

    def parse_metadata(data)
      unless data
        @required_ruby_version = nil
        @required_rubygems_version = nil
        return
      end

      data.each do |k, v|
        next unless v
        case k.to_s
        when "checksum"
          @checksum = v.last
        when "rubygems"
          @required_rubygems_version = Gem::Requirement.new(v)
        when "ruby"
          @required_ruby_version = Gem::Requirement.new(v)
        end
      end
    rescue StandardError => e
      raise GemspecError, "There was an error parsing the metadata for the gem #{name} (#{version}): #{e.class}\n#{e}\nThe metadata was #{data.inspect}"
    end

    def build_dependency(name, requirements)
      Gem::Dependency.new(name, requirements)
    end
  end
end
