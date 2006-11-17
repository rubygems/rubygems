require 'rubygems/remote_fetcher'
require 'rubygems/incremental_fetcher'
require 'rubygems/source_info_cache'
require 'rubygems/source_info_cache_entry'

##
# CachedFetcher is a decorator that adds local file caching to RemoteFetcher
# objects.

class Gem::CachedFetcher

  # The shared cache manager for all CachedFetcher instances.
  def self.manager
    @manager ||= Gem::SourceInfoCache.new
  end

  # Sent by the client when it is done with all the sources, allowing any
  # cleanup activity to take place.
  def self.finish
    manager.flush
  end

  # Create a cached fetcher for the source at +source_uri+ operating through
  # the HTTP proxy +proxy+.
  def initialize(source_uri, proxy)
    @source_uri = source_uri
    remote_fetcher = Gem::RemoteFetcher.new source_uri, proxy
    @fetcher = Gem::IncrementalFetcher.new source_uri, remote_fetcher, manager
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
      manager.cache_data[@source_uri] =
        Gem::SourceInfoCacheEntry.new result, @fetcher.size
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

end

