require 'rubygems'
require 'zlib'

class Gem::SpecFetcher

  def initialize
    @dir = File.join Gem.user_home, '.gem', 'specs'

    @specs = {}
    @latest_specs = {}

    @fetcher = Gem::RemoteFetcher.fetcher
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

        spec = @fetcher.fetch_path uri
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
        specs = load_specs source_uri, file

        cache = all ? @specs : @latest_specs

        cache[source_uri] = specs
        list[source_uri] = specs
      end
    end

    list
  end

  def load_specs(source_uri, file)
    file_name = "#{file}.#{Gem.marshal_version}.gz"

    spec_path = source_uri + file_name

    cache_dir = File.join @dir, "#{spec_path.host}:#{spec_path.port}",
                          File.dirname(spec_path.path)

    local_file = File.join(cache_dir, file_name).chomp '.gz'

    if File.exist? local_file then
      local_size = File.stat(local_file).size

      remote_file = spec_path.dup
      remote_file.path = remote_file.path.chomp '.gz'
      remote_size = @fetcher.fetch_size remote_file

      spec_dump = Gem.read_binary local_file if remote_size == local_size
    end

    unless spec_dump then
      loaded = true

      spec_dump_gz = @fetcher.fetch_path spec_path
      spec_dump = unzip spec_dump_gz
    end

    specs = Marshal.load spec_dump

    if loaded then
      begin
        FileUtils.mkdir_p cache_dir

        open local_file, 'wb' do |io|
          Marshal.dump specs, io
        end
      rescue
      end
    end
    
    specs
  end

  ##
  # GzipWriter wrapper that unzips +data+.

  def unzip(data)
    data = StringIO.new data

    Zlib::GzipReader.new(data).read
  end

end

