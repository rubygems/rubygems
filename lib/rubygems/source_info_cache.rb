require 'rubygems'
require 'rubygems/source_info_cache_entry'

####################################################################
# SourceInfoCache implements the cache management policy on where the source
# info is stored on local file system.  There are two possible cache
# locations: (1) the system wide cache, and (2) the user specific cache.
#
# * The system cache is prefered if it is writable (or can be created).
# * The user cache is used if the system cache is not writable (or can not be
#   created).
#
# Once a cache is selected, it will be used for all operations.  It will not
# switch between cache files dynamically.
#
# Cache data is a simple hash indexed by the source URI.  Retrieving and entry
# from the cache data will return a SourceInfoCacheEntry.
#
class Gem::SourceInfoCache

  def initialize # :nodoc:
    @cache_data = nil
    @cache_file = nil
    @dirty = false
    @system_cache_file = nil
    @user_cache_file = nil
  end

  # The most recent cache data.
  def cache_data
    return @cache_data if @cache_data
    @dirty = false
    cache_file # HACK writable check
    @cache_data = begin
                    open cache_file, "rb" do |f|
                      # Marshal loads 30-40% faster from a String, and 2MB
                      # on 20061116 is small
                      Marshal.load f.read || {}
                    end
                  rescue
                    {}
                  end
  end

  # The name of the cache file to be read
  def cache_file
    return @cache_file if @cache_file
    @cache_file = (try_file(system_cache_file) or
                   try_file(user_cache_file) or
                   raise "unable to locate a writable cache file")
  end

  # Write the cache to a local file (if it is dirty).
  def flush
    write_cache if @dirty
    @dirty = false
  end

  # The name of the system cache file.
  def system_cache_file
    @system_cache_file ||= File.join(Gem.dir, "source_cache")
  end

  # Mark the cache as updated (i.e. dirty).
  def update
    @dirty = true
  end

  # The name of the user cache file.
  def user_cache_file
    @user_cache_file ||=
      ENV['GEMCACHE'] || File.join(Gem.user_home, ".gem", "source_cache")
  end

  # Write data to the proper cache.
  def write_cache
    open cache_file, "wb" do |f|
      f.write Marshal.dump(cache_data)
    end
  end

  private 

  # Determine if +fn+ is a candidate for a cache file.  Return fn if
  # it is.  Return nil if it is not.
  def try_file(fn)
    return fn if File.writable?(fn)
    return nil if File.exist?(fn)
    dir = File.dirname(fn)
    if ! File.exist? dir
      begin
        FileUtils.mkdir_p(dir)
      rescue RuntimeError
        return nil
      end
    end
    if File.writable?(dir)
      FileUtils.touch fn
      return fn
    end
    nil
  end
end

