##
# A semi-compatible DSL for the Bundler Gemfile and Isolate formats.

class Gem::RequestSet::GemDependencyAPI

  java      = Gem::Platform.new 'java'
  mswin     = Gem::Platform.new 'mswin32'
  mingw     = Gem::Platform.new 'x86-mingw32'
  x64_mingw = Gem::Platform.new 'x64-mingw32'

  PLATFORM_MAP = {
    :ruby         => Gem::Platform::RUBY,
    :ruby_18      => Gem::Platform::RUBY,
    :ruby_19      => Gem::Platform::RUBY,
    :ruby_20      => Gem::Platform::RUBY,
    :ruby_21      => Gem::Platform::RUBY,
    :mri          => Gem::Platform::RUBY,
    :mri_18       => Gem::Platform::RUBY,
    :mri_19       => Gem::Platform::RUBY,
    :mri_20       => Gem::Platform::RUBY,
    :mri_21       => Gem::Platform::RUBY,
    :rbx          => Gem::Platform::RUBY,
    :jruby        => java,
    :JRUBY_18     => java,
    :JRUBY_19     => java,
    :MSWIN        => mswin,
    :MINGW        => mingw,
    :MINGW_18     => mingw,
    :MINGW_19     => mingw,
    :MINGW_20     => mingw,
    :MINGW_21     => mingw,
    :X64_MINGW    => x64_mingw,
    :X64_MINGW_20 => x64_mingw,
    :X64_MINGW_21 => x64_mingw
  }

  ##
  # A Hash containing gem names and files to require from those gems.

  attr_reader :requires

  ##
  # A set of gems that are loaded via the +:path+ option to #gem

  attr_reader :vendor_set # :nodoc:

  ##
  # The groups of gems to exclude from installation

  attr_accessor :without_groups

  ##
  # Creates a new GemDependencyAPI that will add dependencies to the
  # Gem::RequestSet +set+ based on the dependency API description in +path+.

  def initialize set, path
    @set = set
    @path = path

    @current_groups  = nil
    @default_sources = true
    @requires        = Hash.new { |h, name|  h[name]  = [] }
    @vendor_set      = @set.vendor_set
    @without_groups  = []
  end

  ##
  # Loads the gem dependency file

  def load
    instance_eval File.read(@path).untaint, @path, 1
  end

  ##
  # :category: Gem Dependencies DSL
  # :call-seq:
  #   gem(name)
  #   gem(name, *requirements)
  #   gem(name, *requirements, options)
  #
  # Specifies a gem dependency with the given +name+ and +requirements+.  You
  # may also supply +options+ following the +requirements+

  def gem name, *requirements
    options = requirements.pop if requirements.last.kind_of?(Hash)
    options ||= {}

    gem_path name, options

    return unless gem_platforms options

    groups = gem_group name, options

    return unless (groups & @without_groups).empty?

    gem_requires name, options

    @set.gem name, *requirements
  end

  ##
  # Handles the :group and :groups +options+ for the gem with the given
  # +name+.

  def gem_group name, options # :nodoc:
    g = options.delete :group
    all_groups  = g ? Array(g) : []

    groups = options.delete :groups
    all_groups |= groups if groups

    all_groups |= @current_groups if @current_groups

    all_groups
  end

  private :gem_group

  ##
  # Handles the path: option from +options+ for gem +name+.

  def gem_path name, options # :nodoc:
    if directory = options.delete(:path) then
      @vendor_set.add_vendor_gem name, directory
    end
  end

  private :gem_path

  ##
  # Handles the platforms: option from +options+.  Returns true if the
  # platform matches the current platform.

  def gem_platforms options # :nodoc:
    return true unless platforms = options.delete(:platforms)

    platforms = PLATFORM_MAP[platforms]

    Gem::Platform.match platforms
  end

  private :gem_platforms

  ##
  # Handles the require: option from +options+ and adds those files, or the
  # default file to the require list for +name+.

  def gem_requires name, options # :nodoc:
    if options.include? :require then
      if requires = options.delete(:require) then
        @requires[name].concat requires
      end
    else
      @requires[name] << name
    end
  end

  private :gem_requires

  ##
  # Returns the basename of the file the dependencies were loaded from

  def gem_deps_file # :nodoc:
    File.basename @path
  end

  ##
  # :category: Gem Dependencies DSL
  # Block form for placing a dependency in the given +groups+.

  def group *groups
    @current_groups = groups

    yield

  ensure
    @current_groups = nil
  end

  ##
  # :category: Gem Dependencies DSL

  def platform what
    if what == :ruby
      yield
    end
  end

  ##
  # :category: Gem Dependencies DSL

  alias :platforms :platform

  ##
  # :category: Gem Dependencies DSL
  # Restricts this gem dependencies file to the given ruby +version+.  The
  # +:engine+ options from Bundler are currently ignored.

  def ruby version, options = {}
    engine         = options[:engine]
    engine_version = options[:engine_version]

    raise ArgumentError,
          'you must specify engine_version along with the ruby engine' if
            engine and not engine_version

    unless RUBY_VERSION == version then
      message = "Your Ruby version is #{RUBY_VERSION}, " +
                "but your #{gem_deps_file} requires #{version}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine and engine != RUBY_ENGINE then
      message = "Your ruby engine is #{RUBY_ENGINE}, " +
                "but your #{gem_deps_file} requires #{engine}"

      raise Gem::RubyVersionMismatch, message
    end

    if engine_version then
      my_engine_version = Object.const_get "#{RUBY_ENGINE.upcase}_VERSION"

      if engine_version != my_engine_version then
        message =
          "Your ruby engine version is #{RUBY_ENGINE} #{my_engine_version}, " +
          "but your #{gem_deps_file} requires #{engine} #{engine_version}"

        raise Gem::RubyVersionMismatch, message
      end
    end

    return true
  end

  ##
  # :category: Gem Dependencies DSL
  #
  # Sets +url+ as a source for gems for this dependency API.

  def source url
    Gem.sources.clear if @default_sources

    @default_sources = false

    Gem.sources << url
  end

  # TODO: remove this typo name at RubyGems 3.0

  Gem::RequestSet::DepedencyAPI = self # :nodoc:

end

