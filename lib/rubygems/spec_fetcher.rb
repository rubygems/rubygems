require 'rubygems'
require 'zlib'

class Gem::SpecFetcher

  def initialize
    @dir = File.join Gem.user_home, '.gem', 'specs'

    @specs = {}
    @latest_specs = {}
  end

  ##
  # Fetch specs matching +dependency+.  If +all+ is true, all matching
  # versions are returned.

  def fetch(dependency, all = false)
    found = find_matching dependency, all

    found.map do |source_uri, specs|
      specs = specs.map do |spec|
        spec = spec - [nil, 'ruby']
        uri = source_uri + "#{Gem::MARSHAL_SPEC_DIR}#{spec.join('-')}.gemspec.rz"

        spec = Gem::RemoteFetcher.fetcher.fetch_path uri
        spec = inflate spec
        Marshal.load spec
      end

      [source_uri, specs]
    end
  end

  ##
  # Find spec names that match +dependency+.  If +all+ is true, all matching
  # versions are returned.

  def find_matching(dependency, all = false)
    found = {}

    list(all).each do |source_uri, specs|
      found[source_uri] = specs.select do |spec_name, version, spec_platform|
        dependency =~ Gem::Dependency.new(spec_name, version) and
          Gem::Platform.match(spec_platform)
      end
    end

    found
  end

  ##
  # Inflate wrapper that inflates +data+.

  def inflate(data)
    Zlib::Inflate.inflate data
  end

  ##
  # Returns a list of gems available for each source in Gem::sources.  If
  # +all+ is true, all versions are returned instead of only latest versions.

  def list(all = false)
    list = {}

    file = all ? 'specs' : 'latest_specs'

    Gem.sources.each do |source_uri|
      source_uri = URI.parse source_uri

      if all and @specs.include? source_uri then
        list[source_uri] = @specs[source_uri]
      elsif @latest_specs.include? source_uri then
        list[source_uri] = @latest_specs[source_uri]
      else
        spec_path = source_uri + "#{file}.#{Gem.marshal_version}.gz"
        spec_dump_gz = Gem::RemoteFetcher.fetcher.fetch_path spec_path
        spec_dump = unzip spec_dump_gz

        specs = Marshal.load spec_dump

        cache = all ? @specs : @latest_specs

        cache[source_uri] = specs
        list[source_uri] = specs
      end
    end

    list
  end

  ##
  # GzipWriter wrapper that unzips +data+.

  def unzip(data)
    data = StringIO.new data

    Zlib::GzipReader.new(data).read
  end

end

