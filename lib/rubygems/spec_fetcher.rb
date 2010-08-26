require 'zlib'
require 'fileutils'

require 'rubygems/remote_fetcher'
require 'rubygems/user_interaction'
require 'rubygems/errors'

##
# SpecFetcher handles metadata updates from remote gem repositories.

class Gem::SpecFetcher

  include Gem::UserInteraction

  ##
  # The SpecFetcher cache dir.

  attr_reader :dir # :nodoc:

  ##
  # Cache of latest specs

  attr_reader :latest_specs # :nodoc:

  ##
  # Cache of all released specs

  attr_reader :specs # :nodoc:

  ##
  # Cache of prerelease specs

  attr_reader :prerelease_specs # :nodoc:

  @fetcher = nil

  def self.fetcher
    @fetcher ||= new
  end

  def self.fetcher=(fetcher) # :nodoc:
    @fetcher = fetcher
  end

  def initialize
    @dir = File.join Gem.user_home, '.gem', 'specs'
    @update_cache = File.stat(Gem.user_home).uid == Process.uid

    @specs = {}
    @latest_specs = {}
    @prerelease_specs = {}

    @fetcher = Gem::RemoteFetcher.fetcher
  end

  ##
  # Returns the local directory to write +uri+ to.

  def cache_dir(uri)
    File.join @dir, "#{uri.host}%#{uri.port}", File.dirname(uri.path)
  end

  ##
  # Fetch specs matching +dependency+.  If +all+ is true, all matching
  # (released) versions are returned.  If +matching_platform+ is
  # false, all platforms are returned. If +prerelease+ is true,
  # prerelease versions are included.

  def fetch_with_errors(dependency, all = false, matching_platform = true, prerelease = false)
    specs_and_sources, errors = find_matching_with_errors dependency, all, matching_platform, prerelease

    ss = specs_and_sources.map do |spec_tuple, source_uri|
      [fetch_spec(spec_tuple, URI.parse(source_uri)), source_uri]
    end

    return [ss, errors]

  rescue Gem::RemoteFetcher::FetchError => e
    raise unless warn_legacy e do
      require 'rubygems/source_info_cache'

      return [Gem::SourceInfoCache.search_with_source(dependency,
                                                     matching_platform, all), nil]
    end
  end

  def fetch(*args)
    fetch_with_errors(*args).first
  end

  def fetch_spec(spec, source_uri)
    spec = spec - [nil, 'ruby', '']
    spec_file_name = "#{spec.join '-'}.gemspec"

    uri = source_uri + "#{Gem::MARSHAL_SPEC_DIR}#{spec_file_name}"

    cache_dir = cache_dir uri

    local_spec = File.join cache_dir, spec_file_name

    if File.exist? local_spec then
      spec = Gem.read_binary local_spec
    else
      uri.path << '.rz'

      spec = @fetcher.fetch_path uri
      spec = Gem.inflate spec

      if @update_cache then
        FileUtils.mkdir_p cache_dir

        open local_spec, 'wb' do |io|
          io.write spec
        end
      end
    end

    # TODO: Investigate setting Gem::Specification#loaded_from to a URI
    Marshal.load spec
  end

  ##
  # Find spec names that match +dependency+.  If +all+ is true, all
  # matching released versions are returned.  If +matching_platform+
  # is false, gems for all platforms are returned.

  def find_matching_with_errors(dependency, all = false, matching_platform = true, prerelease = false)
    found = {}

    rejected_specs = {}

    list(all, prerelease).each do |source_uri, specs|
      found[source_uri] = specs.select do |spec_name, version, spec_platform|
        if dependency.match?(spec_name, version)
          if matching_platform and !Gem::Platform.match(spec_platform)
            pm = (rejected_specs[dependency] ||= Gem::PlatformMismatch.new(spec_name, version))
            pm.add_platform spec_platform
            false
          else
            true
          end
        end
      end
    end

    errors = rejected_specs.values

    specs_and_sources = []

    found.each do |source_uri, specs|
      uri_str = source_uri.to_s
      specs_and_sources.push(*specs.map { |spec| [spec, uri_str] })
    end

    [specs_and_sources, errors]
  end

  def find_matching(*args)
    find_matching_with_errors(*args).first
  end

  ##
  # Returns an Array of gem names similar to +gem_name+.
  #

  def find_similar(gem_name, matching_platform = true)
    matches = []
    #Gem name argument is frozen
    gem_name = gem_name.downcase
    gem_name.gsub!(/_|-/, "")
    limit = gem_name.length / 2  #Limit on how dissimilar two strings can be
    match_limit = 12  #Limit on how many matches to return

    early_break = false
    list.each do |source_uri, specs|
      specs.each do |spec_name, version, spec_platform|
        next if matching_platform and !Gem::Platform.match(spec_platform)

	normalized_spec_name = spec_name.downcase.gsub(/_|-/, "")

	distance = similarity gem_name, normalized_spec_name, limit

	#Consider this a perfect match and return it
        if distance == 0
          return [spec_name]
        end
        
        if distance < limit
          matches << [spec_name, distance]
	  #Only stop early if it has at least inspected gem names starting with the same
	  #letter.
          if matches.length > match_limit and normalized_spec_name[0,1] > gem_name[0,1]
            early_break = true
            break
          end
        end
      end
      break if early_break
    end
    
    #Sort by closest match
    matches = matches.uniq.sort_by { |m| m[1] }.map { |m| m[0] }

    #Limit number of results
    if early_break
      matches = matches[0, match_limit] << "..."
    end

    matches
  end

  ##
  # Returns Array of gem repositories that were generated with RubyGems less
  # than 1.2.

  def legacy_repos
    Gem.sources.reject do |source_uri|
      source_uri = URI.parse source_uri
      spec_path = source_uri + "specs.#{Gem.marshal_version}.gz"

      begin
        @fetcher.fetch_size spec_path
      rescue Gem::RemoteFetcher::FetchError
        begin
          @fetcher.fetch_size(source_uri + 'yaml') # re-raise if non-repo
        rescue Gem::RemoteFetcher::FetchError
          alert_error "#{source_uri} does not appear to be a repository"
          raise
        end
        false
      end
    end
  end

  ##
  # Returns a list of gems available for each source in Gem::sources.  If
  # +all+ is true, all released versions are returned instead of only latest
  # versions. If +prerelease+ is true, include prerelease versions.

  def list(all = false, prerelease = false)
    # TODO: make type the only argument
    type = if all
             :all
           elsif prerelease
             :prerelease
           else
             :latest
           end

    list = {}

    file = { :latest => 'latest_specs',
      :prerelease => 'prerelease_specs',
      :all => 'specs' }[type]

    cache = { :latest => @latest_specs,
      :prerelease => @prerelease_specs,
      :all => @specs }[type]

    Gem.sources.each do |source_uri|
      source_uri = URI.parse source_uri

      unless cache.include? source_uri
        cache[source_uri] = load_specs source_uri, file
      end

      list[source_uri] = cache[source_uri]
    end

    if type == :all
      list.values.map do |gems|
        gems.reject! { |g| !g[1] || g[1].prerelease? }
      end
    end

    list
  end

  ##
  # Loads specs in +file+, fetching from +source_uri+ if the on-disk cache is
  # out of date.

  def load_specs(source_uri, file)
    file_name  = "#{file}.#{Gem.marshal_version}"
    spec_path  = source_uri + "#{file_name}.gz"
    cache_dir  = cache_dir spec_path
    local_file = File.join(cache_dir, file_name)
    loaded     = false

    if File.exist? local_file then
      spec_dump = @fetcher.fetch_path spec_path, File.mtime(local_file)

      if spec_dump.nil? then
        spec_dump = Gem.read_binary local_file
      else
        loaded = true
      end
    else
      spec_dump = @fetcher.fetch_path spec_path
      loaded = true
    end

    specs = begin
              Marshal.load spec_dump
            rescue ArgumentError
              spec_dump = @fetcher.fetch_path spec_path
              loaded = true

              Marshal.load spec_dump
            end

    if loaded and @update_cache then
      begin
        FileUtils.mkdir_p cache_dir

        open local_file, 'wb' do |io|
          io << spec_dump
        end
      rescue
      end
    end

    specs
  end

  ##
  # Returns a number indicating how similar the +input+ is to a given
  # +gem_name+.
  # +limit+ sets an upper limit on how dissimilar two strings can be, but the
  # method may still return a higher number.
  # 
  # 0 is considered a perfect match, but note the function does some processing
  # on the strings, so this is not the same as +input+ == +gem_name+.

  def similarity input, gem_name, limit
    #Check for same string
    return 0 if input == gem_name

    len1 = input.length
    len2 = gem_name.length
  
    #Check if input matches beginning of gem name
    #But not if the input is tiny
    if len1 > 3 and gem_name[0, len1] == input
      return limit - 1
    end

    #Check if string lengths are too different
    return limit if (len1 - len2).abs > limit

    #Compute Damerau–Levenshtein distance
    #Based on http://gist.github.com/182759
    oneago = nil
    row = (1..len2).to_a << 0
    len1.times do |i|
      twoago, oneago, row = oneago, row, Array.new(len2) {0} << (i + 1)
      len2.times do |j|
        cost = input[i] == gem_name[j] ? 0 : 1
        delcost = oneago[j] + 1
        addcost = row[j - 1] + 1
        subcost = oneago[j - 1] + cost
        row[j] = [delcost, addcost, subcost].min
        if i > 0 and j > 0 and input[i] == gem_name[j-1] and 
                input[i-1] == gem_name[j]
           row[j] = [row[j], twoago[j - 2] + cost].min
        end
      end
    end
    
    row[len2 - 1]
  end

  private :similarity

  # Warn about legacy repositories if +exception+ indicates only legacy
  # repositories are available, and yield to the block.  Returns false if the
  # exception indicates some other FetchError.

  def warn_legacy(exception)
    uri = exception.uri.to_s
    if uri =~ /specs\.#{Regexp.escape Gem.marshal_version}\.gz$/ then
      alert_warning <<-EOF
RubyGems 1.2+ index not found for:
\t#{legacy_repos.join "\n\t"}

RubyGems will revert to legacy indexes degrading performance.
      EOF

      yield

      return true
    end

    false
  end

end

