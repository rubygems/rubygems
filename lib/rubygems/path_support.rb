##
#
# Gem::PathSupport facilitates the GEM_* environment environment settings
# to the rest of RubyGems.
#
# * GEM_HOME - path for managing gems
# * GEM_PATH - search path for finding gems
# * GEM_SPEC_CACHE - local file cache for /latest_specs.4.8
# * GEM_FETCH_CACHE - local file cache for remote .gem files
#
class Gem::PathSupport
  ##
  # The default system path for managing Gems.
  attr_reader :home

  ##
  # Array of paths to search for Gems.
  attr_reader :path

  ##
  # Directory with fetch cache
  attr_reader :fetch_cache_dir # :nodoc:
  alias spec_cache_dir fetch_cache_dir # :nodoc:

  ##
  #
  # Constructor. Takes a single argument which is to be treated like a
  # hashtable, or defaults to ENV, the system environment.
  #
  def initialize(env=ENV)
    @env = env

    # note 'env' vs 'ENV'...
    @home     = env["GEM_HOME"] || ENV["GEM_HOME"] || Gem.default_dir

    if File::ALT_SEPARATOR then
      @home   = @home.gsub(File::ALT_SEPARATOR, File::SEPARATOR)
    end
    @fetch_cache_dir = env["GEM_FETCH_CACHE"] || ENV["GEM_FETCH_CACHE"] ||
                env["GEM_SPEC_CACHE"] || ENV["GEM_SPEC_CACHE"] ||
                Gem.default_fetch_cache_dir
    @fetch_cache_dir = @fetch_cache_dir.dup.untaint

    self.path = env["GEM_PATH"] || ENV["GEM_PATH"]
  end

  private

  ##
  # Set the Gem home directory (as reported by Gem.dir).

  def home=(home)
    @home = home.to_s
  end

  ##
  # Set the Gem search path (as reported by Gem.path).

  def path=(gpaths)
    # FIX: it should be [home, *path], not [*path, home]

    gem_path = []

    # FIX: I can't tell wtf this is doing.
    gpaths ||= (ENV['GEM_PATH'] || "").empty? ? nil : ENV["GEM_PATH"]

    if gpaths
      if gpaths.kind_of?(Array)
        gem_path = gpaths.dup
      else
        gem_path = gpaths.split(Gem.path_separator)
      end

      if File::ALT_SEPARATOR then
        gem_path.map! do |this_path|
          this_path.gsub File::ALT_SEPARATOR, File::SEPARATOR
        end
      end

      gem_path << @home
    else
      gem_path = Gem.default_path + [@home]

      if defined?(APPLE_GEM_HOME)
        gem_path << APPLE_GEM_HOME
      end
    end

    @path = gem_path.uniq
  end
end
