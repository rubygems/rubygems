##
# Gem::StubSpecification reads the stub: line from the gemspec.  This prevents
# us having to eval the entire gemspec in order to find out certain
# information.

class Gem::StubSpecification < Gem::BasicSpecification
  # :nodoc:
  PREFIX = "# stub: "

  OPEN_MODE = # :nodoc:
    if Object.const_defined? :Encoding then
      'r:UTF-8:-'
    else
      'r'
    end

  class StubLine # :nodoc: all
    attr_reader :name, :version, :platform, :require_paths, :extensions

    NO_EXTENSIONS = [].freeze

    # These are common require paths.
    REQUIRE_PATHS = { # :nodoc:
      'lib'  => 'lib'.freeze,
      'test' => 'test'.freeze,
      'ext'  => 'ext'.freeze,
    }

    def initialize data, extensions
      parts          = data[PREFIX.length..-1].split(" ".freeze)
      @name          = parts[0].freeze
      @version       = Gem::Version.new parts[1]
      @platform      = Gem::Platform.new(parts[2])
      @extensions    = extensions
      @require_paths = parts.drop(3).join(" ".freeze).split("\0".freeze).map! { |x|
        REQUIRE_PATHS[x] || x
      }
    end
  end

  def self.default_gemspec_stub filename
    new filename, true
  end

  def self.gemspec_stub filename
    new filename, false
  end

  def initialize filename, default_gem
    filename.untaint

    self.loaded_from = filename
    @data            = nil
    @name            = nil
    @spec            = nil
    @default_gem     = default_gem
  end

  ##
  # True when this gem has been activated

  def activated?
    @activated ||=
    begin
      loaded = Gem.loaded_specs[name]
      loaded && loaded.version == version
    end
  end

  def default_gem?
    @default_gem
  end

  def build_extensions # :nodoc:
    return if default_gem?
    return if extensions.empty?

    to_spec.build_extensions
  end

  ##
  # If the gemspec contains a stubline, returns a StubLine instance. Otherwise
  # returns the full Gem::Specification.

  def data
    unless @data
      begin
        saved_lineno = $.
        open loaded_from, OPEN_MODE do |file|
          begin
            file.readline # discard encoding line
            stubline = file.readline.chomp
            if stubline.start_with?(PREFIX) then
              extensions = if /\A#{PREFIX}/ =~ file.readline.chomp
                             $'.split "\0"
                           else
                             StubLine::NO_EXTENSIONS
                           end

              @data = StubLine.new stubline, extensions
            end
          rescue EOFError
          end
        end
      ensure
        $. = saved_lineno
      end
    end

    @data ||= to_spec
  end

  private :data

  ##
  # If a gem has a stub specification it doesn't need to bother with
  # compatibility with original_name gems.  It was installed with the
  # normalized name.

  def find_full_gem_path # :nodoc:
    path = File.expand_path File.join gems_dir, full_name
    path.untaint
    path
  end

  def raw_require_paths # :nodoc:
    data.require_paths
  end

  def missing_extensions?
    return false if default_gem?
    return false if extensions.empty?
    return false if File.exist? gem_build_complete_path

    to_spec.missing_extensions?
  end

  ##
  # Name of the gem

  def name
    data.name
  end

  ##
  # Platform of the gem

  def platform
    data.platform
  end

  ##
  # Extensions for this gem

  def extensions
    data.extensions
  end

  ##
  # The full Gem::Specification for this gem, loaded from evalling its gemspec

  def to_spec
    @spec ||= if @data then
                Gem.loaded_specs.values.find { |spec|
                  spec.name == name and spec.version == version
                }
              end

    @spec ||= Gem::Specification.load(loaded_from)
    @spec.ignored = @ignored if instance_variable_defined? :@ignored

    @spec
  end

  ##
  # Is this StubSpecification valid? i.e. have we found a stub line, OR does
  # the filename contain a valid gemspec?

  def valid?
    data
  end

  ##
  # Version of the gem

  def version
    @version ||= data.version
  end

  ##
  # Is there a stub line present for this StubSpecification?

  def stubbed?
    data.is_a? StubLine
  end

end

