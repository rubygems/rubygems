require 'uri'
require 'fileutils'
require 'rubygems/path_support'

##
# A RemoteFetcherCache keeps track of remote uris and their local cached
# versions.

class Gem::RemoteFetcherCache
  def initialize(paths = Gem.paths)
    @paths = paths
    init_cache_dir(fetch_cache_dir)
  end

  def fetch_cache_dir
    @paths.fetch_cache_dir
  end

  ##
  # Fetch the data from the given uri key.
  # If the data does not exist, and the block is given, the execute the block
  # and store the data returned from the block at the given uri key.

  def fetch(uri, mtime = Time.now, &block)
    data = nil

    if stale?(uri,mtime) && block_given? then
      data = block.call
      store(uri, data, mtime)
    else
      data = Gem.read_binary(cache_path_for(uri))
    end

    data
  end

  ##
  # Return whether or not the cache entry for the given uri is stale based upon
  # the given mtime.
  #
  # If the uri does not exist in the cache, then return true

  def stale?(uri, mtime = Time.now)
    mtime ||= Time.now
    stat = File.stat( cache_path_for(uri) )
    stat.mtime.to_i < mtime.to_i
  rescue Errno::ENOENT
    true
  end

  ##
  # Store the given data in the cache. Return true or false if the data was
  # stored or not.
  #
  # If the uri ends with a '/' we ignore it as that would be storing a directory

  def store(uri, data, mtime = Time.now)
    return false if uri.to_s.end_with?("/")
    cache_path = cache_path_for(uri)
    dirname = File.dirname(cache_path)
    FileUtils.mkdir_p(dirname) unless File.directory? dirname
    File.open(cache_path, 'wb+') do |io|
      io.flock(File::LOCK_EX)
      io.write data
    end
    File.utime(mtime,mtime,cache_path)
    true
  end

  def include?(uri)
    File.exist? cache_path_for(uri)
  end

  ##
  # Returns the local path to write +uri+ to.

  def cache_path_for(uri)
    File.join fetch_cache_dir, "#{uri.host}%#{uri.port}", escape_path(uri)
  end

  ##
  # Returns the local directory to write +uri+ to.
  def cache_dir(uri)
    File.dirname cache_path_for( uri )
  end

  ##
  # escape_path
  def escape_path(uri)
    # Correct for windows paths
    escaped_path = uri.path.sub(/^\/([a-z]):\//i, '/\\1-/')
    escaped_path.untaint
  end

  private

  ##
  # Creates the cache dir if it doesn't exist.
  # Raises an error if the cache cannot be created.

  def init_cache_dir(dir)
    if File.exist?(dir) then
      raise Gem::Exception, "Cache dir (#{dir}) is not owned by current uid (#{Process.uid})" unless
        File.owned?(dir)
    else
      FileUtils.mkdir_p(dir)
    end
  rescue Errno::EACCES
    raise Gem::Exception, "Unable to create cache dir (#{dir})"
  end

end
