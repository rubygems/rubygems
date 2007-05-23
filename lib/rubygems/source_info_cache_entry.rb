require 'rubygems'
require 'rubygems/source_index'
require 'rubygems/remote_fetcher'

##
# Entrys held by a SourceInfoCache.

class Gem::SourceInfoCacheEntry

  # The source index for this cache entry.
  attr_reader :source_index

  # The size of the of the source entry.  Used to determine if the
  # source index has changed.
  attr_reader :size

  # Create a cache entry.
  def initialize(si, size)
    @source_index = si || Gem::SourceIndex.new({})
    @size = size
  end

  def refresh(source_uri)
    remote_size = Gem::RemoteFetcher.fetcher.fetch_size source_uri + '/yaml'
    return if @size == remote_size # HACK bad check, local cache not YAML
    @source_index.update source_uri
    @size = remote_size
  end

  def ==(other) # :nodoc:
    self.class === other and
    @size == other.size and
    @source_index == other.source_index
  end

end

