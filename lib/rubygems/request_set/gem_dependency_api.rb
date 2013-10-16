##
# A semi-compatible DSL for Bundler's Gemfile format

class Gem::RequestSet::GemDependencyAPI

  def initialize set, path
    @set = set
    @path = path
  end

  def load
    instance_eval File.read(@path).untaint, @path, 1
  end

  # :category: Bundler Gemfile DSL

  def gem name, *reqs
    # Ignore the opts for now.
    reqs.pop if reqs.last.kind_of?(Hash)

    @set.gem name, *reqs
  end

  ##
  # Returns the basename of the file the dependencies were loaded from

  def gem_deps_file # :nodoc:
    File.basename @path
  end

  def group *what
  end

  def platform what
    if what == :ruby
      yield
    end
  end

  alias :platforms :platform

  ##
  # Restricts this gem dependencies file to the given ruby +version+.  The
  # +:engine+ options from Bundler are currently ignored.

  def ruby version, options = {}
    return true if version == RUBY_VERSION

    message = "Your Ruby version is #{RUBY_VERSION}, " +
              "but your #{gem_deps_file} specified #{version}"

    raise Gem::RubyVersionMismatch, message
  end

  def source url
  end

  # TODO: remove this typo name at RubyGems 3.0

  Gem::RequestSet::DepedencyAPI = self # :nodoc:

end

