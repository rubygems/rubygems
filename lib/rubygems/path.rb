##
#
# Gem::Path is a portable and minimal path handling library that assists with
# the common problem of converting between strings and path information. In
# many instances it can be treated both as a string and a quasi-Pathname
# object.
#
class Gem::Path

  ##
  #
  # Constructor. Takes a list of path parts, which are joined and then the path
  # is expanded. Optionally takes a Pathname object as its first argument,
  # which is converted to string and expanded.
  #
  def initialize(*paths)
    # we do it this way to avoid requiring pathname
    if paths.length == 1 and paths[0].class.name == "Pathname"
      @path = File.expand_path(paths[0].to_s)
    else
      @path = File.expand_path(File.join(paths))
    end
  end

  ##
  #
  # Is this path readable?
  #
  def readable?
    File.readable?(@path)
  end

  ##
  #
  # Is this path writable?
  #
  def writable?
    File.writable?(@path)
  end

  alias path dup

  ##
  #
  # Append to this path. A new object will be returned.
  #
  def add(*parts)
    Gem::Path.new(@path, *parts)
  end

  alias / add

  ##
  #
  # Remove data from any part of the path. Exercise caution using this method.
  #
  def subtract(part)
    Gem::Path.new(@path.sub(part, ''))
  end

  alias - subtract

  ##
  #
  # Obtain the filesize for this path. See File.size
  #
  def size
    File.size(@path)
  end

  ##
  #
  # Obtain the dirname for this path. See File.dirname
  #
  def dirname
    Gem::Path.new(File.dirname(@path))
  end

  ##
  # Does this path exist?
  #
  def exist?
    File.exist?(@path)
  end

  ## 
  #
  # Obtain a list of Gem::Path objects given a glob pattern. See Dir.glob.
  #
  def glob(pattern)
    Dir.glob(File.join(@path, pattern)).map { |x| Gem::Path.new(x) }
  end

  ##
  #
  # Obtain a File::Stat structure for the path. See File.stat and File::Stat.
  #
  def stat
    File.stat(@path)
  end

  ##
  #
  # Is this path a directory?
  #
  def directory?
    File.directory?(@path)
  end

  ##
  #
  # Convert this path to a string.
  #
  def to_s
    @path.dup
  end

  alias to_str to_s

  ##
  #
  # Perform a regular expression match on this path. See String#=~
  #
  def =~(regex)
    @path =~ regex
  end

  ##
  #
  # Does this path equal another path? Anything that responds to .to_s works
  # here!
  #
  def eql?(other_path)
    @path.eql?(other_path.to_s)
  end

  alias == eql?

  ##
  #
  # Compute a hash based on the path. See String#hash.
  #
  def hash
    @path.hash
  end
end
