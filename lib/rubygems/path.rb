##
#
# Gem::Path is a portable and minimal path handling library that assists with
# the common problem of converting between strings and path information. In
# many instances it can be treated both as a string and a quasi-Pathname
# object.
#
class Gem::Path

  include Comparable

  ##
  #
  # Constructor. Takes a list of path parts, which are joined and then the path
  # is expanded. Optionally takes a Pathname object as its first argument,
  # which is converted to string and expanded.
  #
  def initialize(*paths)
    # we do it this way to avoid requiring pathname
    if paths.length == 1 and paths[0].class.name == "Pathname"
      @path = paths[0].to_s
    else
      @path = File.join(paths)
    end
  end

  ##
  #
  # Expand the path. See File.expand_path.
  #
  def expand_path(*args)
    Gem::Path.new(File.expand_path(@path, *args))
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

  ##
  #
  # Is this path a file?
  #
  def file?
    File.file?(@path)
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
  # Appends the path and another string. Returns a string, not a Gem::Path.
  #
  def +(other_str)
    @path + other_str
  end

  ##
  #
  # Remove data from any part of the path. Exercise caution using this method.
  #
  def subtract(part)
    Gem::Path.new(@path.sub(part, ''))
  end

  ##
  #
  # Split the path by the path separator.
  #
  # Returns strings, not Gem::Path objects.
  #
  def split
    array = []

    lead = @path
    
    while tmp = File.split(lead)

      lead, part = *tmp

      array.unshift(part)
      if lead == array[0]
        break
      end
    end

    return array
  end

  ##
  #
  # Compute the relative path based on the existing path minus the passed path:
  #
  #   p = Gem::Path.new('/path/to/something')
  #   p.relative('/path/to').to_s #=> 'something'
  #
  def relative(path)

    if @path == path.to_s
      return self
    end

    passed_parts = path.kind_of?(Gem::Path) ? path.split : Gem::Path.new(path).split
    internal_parts = split

    part = nil

    while true
      part = internal_parts.shift

      if part != passed_parts.shift
        break
      end
    end

    internal_parts.unshift(part)

    Gem::Path.new(internal_parts)
  end

  ##
  #
  # Obtain the filesize for this path. See File.size
  #
  def size
    File.size(@path)
  end

  ##
  #
  # Read the full contents of path and return a string. See File.read.
  #
  def read(*args)
    File.read(@path, *args)
  end

  ##
  #
  # Obtain the dirname for this path. See File.dirname
  #
  def dirname
    Gem::Path.new(File.dirname(@path))
  end
  
  ##
  #
  # Obtain the dirname for this path. See File.dirname
  #
  def basename(ext='')
    Gem::Path.new(File.basename(@path, ext))
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
  # due to how ruby treats these variables, this will not fill $1, $2, etc
  # properly. Use #to_s =~.
  #
  def =~(regex)
    @path =~ regex
  end

  ##
  #
  # Perform a substitution on the path.
  #
  def sub(regex, replacement=nil, &block)
    if replacement
      Gem::Path.new(@path.sub(regex, replacement))
    else
      Gem::Path.new(@path.sub(regex, &block))
    end
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

  ##
  #
  # Comparison operator. Used by Comparable.
  #
  def <=>(obj)
    @path <=> obj.to_s
  end
end
