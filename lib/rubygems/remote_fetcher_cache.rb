require 'uri'
require 'fileutils'
require 'rubygems/path_support'

##
# A RemoteFetcherCache keeps track of remote uris and their local cached
# versions.

class Gem::RemoteFetcherCache
  def initialize(paths = Gem.paths)
    @paths = paths
    @update_cache = nil
    FileUtils.mkdir_p @paths.fetch_cache_dir unless update_cache?
  end

  def fetch_cache_dir
    @paths.fetch_cache_dir
  end

  def fetch(uri, mtime = Time.now.to_i)
    cache_path = cache_path_for uri
    return nil unless File.exist? cache_path
    Gem.read_binary cache_path
  end

  def store(uri, data, mtime = Time.now.to_i)
    return nil unless update_cache?
    cache_path = cache_path_for(uri)
    dirname = File.basename(cache_path)
    File.mkdir_p(dirname) unless File.directory? dirname
    File.open(cache_path, 'wb') do |io|
      io.flock(File::LOCK_EX)
      io.write data
    end
    File.utime(mtime,mtime,cache_path)
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

  ##
  # Returns true when it is possible and safe to update the cache directory.

  def update_cache?
    @update_cache ||=
      begin
        File.stat(fetch_cache_dir).uid == Process.uid
      rescue Errno::ENOENT
        false
      end
  end

end
