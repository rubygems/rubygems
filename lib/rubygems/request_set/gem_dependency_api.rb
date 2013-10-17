##
# A semi-compatible DSL for Bundler's Gemfile format

class Gem::RequestSet::GemDependencyAPI

  ##
  # The dependency groups created by #group in the dependency API file.

  attr_reader :dependency_groups

  def initialize set, path
    @set = set
    @path = path

    @current_groups    = nil
    @dependency_groups = Hash.new { |h, group| h[group] = [] }
  end

  def load
    instance_eval File.read(@path).untaint, @path, 1
  end

  # :category: Bundler Gemfile DSL

  def gem name, *reqs
    # Ignore the opts for now.
    options = reqs.pop if reqs.last.kind_of?(Hash)
    options ||= {}

    groups =
      (group = options.delete(:group) and Array(group)) ||
      options.delete(:groups) ||
      @current_groups

    if groups then
      groups.each do |group|
        gem_arguments = [name, *reqs]
        gem_arguments << options unless options.empty?
        @dependency_groups[group] << gem_arguments
      end
    else
      @set.gem name, *reqs
    end
  end

  ##
  # Returns the basename of the file the dependencies were loaded from

  def gem_deps_file # :nodoc:
    File.basename @path
  end

  ##
  # Block form for placing a dependency in the given +groups+.

  def group *groups
    @current_groups = groups

    yield

  ensure
    @current_groups = nil
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

