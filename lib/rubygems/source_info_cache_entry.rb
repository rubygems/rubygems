require 'rubygems'
require 'rubygems/source_index'

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
    replace_source_index(si, size)
  end

  # Replace the source index and the index size with given values.
  def replace_source_index(si, size)
    @source_index = si || Gem::SourceIndex.new({})
    @size = size
  end

end

