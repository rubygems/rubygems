require 'uri'
require 'fileutils'

##
# A Source knows how to list and fetch gems from a RubyGems marshal index.
#
# There are other Source subclasses for installed gems, local gems, the
# bundler dependency API and so-forth.

class Gem::Source

  include Comparable

  FILES = { # :nodoc:
    :released   => 'specs',
    :latest     => 'latest_specs',
    :prerelease => 'prerelease_specs',
  }

  ##
  # The URI this source will fetch gems from.

  attr_reader :uri

  ##
  # Creates a new Source which will use the index located at +uri+.

  def initialize(uri)
    unless uri.kind_of? URI
      uri = URI.parse(uri.to_s)
    end

    @uri = uri
    @api_uri = nil
  end

  ##
  # Use an SRV record on the host to look up the true endpoint for the index.

  def api_uri # :nodoc:
    require 'rubygems/remote_fetcher'
    @api_uri ||= Gem::RemoteFetcher.fetcher.api_endpoint uri
  end

  ##
  # Sources are ordered by installation preference.

  def <=>(other)
    case other
    when Gem::Source::Installed,
         Gem::Source::Local,
         Gem::Source::Lock,
         Gem::Source::SpecificFile,
         Gem::Source::Git,
         Gem::Source::Vendor then
      -1
    when Gem::Source then
      if !@uri
        return 0 unless other.uri
        return 1
      end

      return -1 if !other.uri

      @uri.to_s <=> other.uri.to_s
    else
      nil
    end
  end

  def == other # :nodoc:
    self.class === other and @uri == other.uri
  end

  alias_method :eql?, :== # :nodoc:

  ##
  # Returns a Set that can fetch specifications from this source.

  def dependency_resolver_set # :nodoc:
    return Gem::Resolver::IndexSet.new self if 'file' == api_uri.scheme

    bundler_api_uri = api_uri + './api/v1/dependencies'

    begin
      fetcher = Gem::RemoteFetcher.fetcher
      response = fetcher.fetch_path bundler_api_uri, nil, true
    rescue Gem::RemoteFetcher::FetchError
      Gem::Resolver::IndexSet.new self
    else
      if response.respond_to? :uri then
        Gem::Resolver::APISet.new response.uri
      else
        Gem::Resolver::APISet.new bundler_api_uri
      end
    end
  end

  def hash # :nodoc:
    @uri.hash
  end

  ##
  # Fetches a specification for the given +name_tuple+.

  def fetch_spec name_tuple
    fetcher = Gem::RemoteFetcher.fetcher

    spec_file_name = name_tuple.spec_name

    uri = api_uri + "#{Gem::MARSHAL_SPEC_DIR}#{spec_file_name}"

    uri.path << '.rz'

    spec = fetcher.fetch_path uri
    spec = Gem.inflate spec

    # TODO: Investigate setting Gem::Specification#loaded_from to a URI
    Marshal.load spec
  end

  ##
  # Loads +type+ kind of specs fetching from +@uri+ if the on-disk cache is
  # out of date.
  #
  # +type+ is one of the following:
  #
  # :released   => Return the list of all released specs
  # :latest     => Return the list of only the highest version of each gem
  # :prerelease => Return the list of all prerelease only specs
  #

  def load_specs(type)
    file       = FILES[type]
    fetcher    = Gem::RemoteFetcher.fetcher
    file_name  = "#{file}.#{Gem.marshal_version}"
    spec_path  = api_uri + "#{file_name}.gz"

    spec_dump = fetcher.fetch_path spec_path

    begin
      Gem::NameTuple.from_list Marshal.load(spec_dump)
    rescue ArgumentError
      raise Gem::Exception.new("Invalid spec cache file for #{spec_path}")
    end
  end

  ##
  # Downloads +spec+ and writes it to +dir+.  See also
  # Gem::RemoteFetcher#download.

  def download(spec, dir=Dir.pwd)
    fetcher = Gem::RemoteFetcher.fetcher
    fetcher.download spec, api_uri.to_s, dir
  end

  def pretty_print q # :nodoc:
    q.group 2, '[Remote:', ']' do
      q.breakable
      q.text @uri.to_s

      if api = api_uri
        q.breakable
        q.text 'API URI: '
        q.text api.to_s
      end
    end
  end

end

require 'rubygems/source/git'
require 'rubygems/source/installed'
require 'rubygems/source/specific_file'
require 'rubygems/source/local'
require 'rubygems/source/lock'
require 'rubygems/source/vendor'

