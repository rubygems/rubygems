gem 'minitest', '~> 4.0'

require 'minitest/autorun'
require 'minitest/mock'
require 'minitest/spec'
require 'delegate'
require 'tmpdir'

require 'rubygems/test_case'
require 'rubygems/indexer'

module Bundler
  VERSION = '1.6.4'

  class Bundler::GemfileError < RuntimeError
  end

  class Dependency < DelegateClass(Gem::Dependency)

    attr_accessor :source

    def self.from dep
      new dep.name, dep.requirement
    end

    def initialize name, requirement, options = {}
      dep = Gem::Dependency.new name, requirement

      super dep

      @source = options['source']
    end
  end

  class Dsl < DelegateClass(Gem::RequestSet::GemDependencyAPI)
    def self.evaluate path, b, c
      request_set = Gem::RequestSet.new

      api = new
      api.__getobj__.instance_variable_set :@path, path
      api.load
    end

    def initialize
      @request_set = Gem::RequestSet.new
      @path        = 'Gemfile'
      @git_set     = Gem::Resolver::GitSet.new

      @request_set.instance_variable_set :@git_set, @git_set

      @api = Gem::RequestSet::GemDependencyAPI.new @request_set, @path

      super @api
    end

    def dependencies
      @request_set.dependencies.map do |dep|
        b_dep = Bundler::Dependency.from dep

        repository, = @git_set.repositories[dep.name]

        b_dep.source = Bundler::Source::Git.new repository if repository

        b_dep
      end
    end

    def eval_gemfile path
      __getobj__.instance_variable_set :@path, path

      load
    end

    def gem *a
      super
    rescue ArgumentError => e
      message =
        case e.message
        when /unknown platform / then
          "#{$'} is not a valid platform"
        else
          e.message
        end

      raise Bundler::GemfileError, message
    end

    def load
      super
    rescue NameError => e
      path = __getobj__.instance_variable_get :@path

      message = e.message.capitalize
      message.sub!(/#.*/, path)
      message << "\nfrom #{e.backtrace[0]}"

      raise Bundler::GemfileError, message
    rescue SyntaxError
      raise Bundler::GemfileError, 'Gemfile syntax error'
    end
  end

  module Source
    module Rubygems
    end

    class Git
      attr_reader :uri

      def initialize uri
        @uri = uri
      end
    end
  end

  def self.read_file name
    File.read name
  end

end

module Bundler::GemHelpers

  include Gem::DefaultUserInteraction

  attr_accessor :fetcher
  attr_accessor :gem_repo
  attr_accessor :uri

  def setup
    super

    @stubs = []

    @orig_gem_home   = ENV['GEM_HOME']
    @orig_gem_path   = ENV['GEM_PATH']
    @orig_gem_vendor = ENV['GEM_VENDOR']
    @orig_ENV_HOME = ENV['HOME']

    ENV['GEM_VENDOR'] = nil

    @expect   = nil
    @fetcher  = nil
    @gem_repo = 'http://gems.example/'
    @uri      = URI.parse @gem_repo
    Gem.sources.replace [@gem_repo]

    @tmpdir   = Dir.mktmpdir 'rubygems-bundler'
    @gemhome  = File.join @tmpdir, 'gemhome'
    @userhome = File.join @tmpdir, 'userhome'

    Gem.instance_variable_set :@user_home, nil
    Gem.use_paths @gemhome

    FileUtils.mkdir_p @gemhome
    FileUtils.mkdir_p @userhome

    @pwd = Dir.pwd
    Dir.chdir @tmpdir

    spec_fetcher do |fetcher|
      fetcher.gem 'activemerchant', '1.0' do |s|
        s.add_dependency 'activesupport', '>= 2.0.0'
      end

      fetcher.gem 'activesupport', '1.2.3'
      fetcher.gem 'activesupport', '2.3.2'
      fetcher.gem 'activesupport', '2.3.5'
      fetcher.gem 'bundler', '0.9.2'
      fetcher.gem 'bundler', Bundler::VERSION
      fetcher.gem 'rack',    '0.9.1'
      fetcher.gem 'rack',    '1.0.0'
      fetcher.gem 'rails',   '3.0.0'
      fetcher.gem 'rails',   '4.0.0'

      fetcher.gem 'rails_fail', '1.0' do |s|
        s.add_dependency 'activesupport', '= 1.2.3'
      end

      fetcher.gem 'multiple_versioned_deps', '1.0' do |s|
        s.add_dependency 'weakling', '>= 0.0.1', '< 0.1'
      end

      fetcher.gem 'weakling', '0.0.3'
    end

    build_repo gem_repo1
  end

  def teardown
    @stubs.each do |klass, name, stub_name|
      klass.send :undef_method, name
      klass.send :alias_method, name, stub_name
      klass.send :undef_method, stub_name
    end

    Dir.chdir @pwd
    FileUtils.rm_f @tmpdir
  end

  def allow a
  end

  def and_return result
    name = @receive

    if @expect == Bundler and :read_file == name then
      @expect = File
      name  = :read
    end

    # from minitest/mock
    stub_name = "__stub__#{name}"

    sclass = @expect.singleton_class

    sclass.send :alias_method, stub_name, name

    sclass.send :define_method, name do |*args|
      result
    end

    @stubs << [sclass, name, stub_name]
  end

  def build_gem name, version = '1.0', **options
    @spec_fetcher_setup.gem name, version do |spec|
      yield spec if block_given?
    end

    if options[:gemspec] then
      spec = Gem::Specification.new do |s|
        s.platform    = Gem::Platform::RUBY
        s.name        = name
        s.version     = version
        s.author      = 'A User'
        s.email       = 'example@example.com'
        s.homepage    = 'http://example.com'
        s.summary     = 'this is a summary'
        s.description = 'This is a test description'

        yield s if block_given?
      end

      File.write spec.spec_name, spec.to_yaml
    else
      @spec_fetcher_setup.gem name, version do |spec|
        yield spec if block_given?
      end
    end
  end

  def build_git a, b = nil
  end

  def build_lib a, b = nil
  end

  def build_repo repo
    gems      = File.join @tmpdir, 'gems'
    repo_gems = File.join repo, 'gems'

    FileUtils.mkdir_p repo
    FileUtils.mv gems, repo_gems

    Gem::Indexer.new(repo).generate_index

    FileUtils.rm_r @gemhome

    Gem::Specification.reset
  end

  def build_repo2
    Gem::TestCase::SpecFetcherSetup.declare self, @gem_repo do |spec_fetcher_setup|
      @spec_fetcher_setup = spec_fetcher_setup
      yield if block_given?
      @spec_fetcher_setup = nil
    end

    build_repo gem_repo2
  end

  def bundle command, options = {}
    if artifice = options.delete(:artifice) then
      case artifice
      when 'endpoint_marshal_fail' then
        @fetcher.data["#{@gem_repo}api/v1/dependencies"] = 'f0283y01hasf'
      else
        raise "unknown artifice #{artifice}"
      end
    end

    case command
    when 'check' then
      rs = Gem::RequestSet.new
      rs.load_gemdeps 'Gemfile'

      rs.resolve_current

      @out = "The Gemfile's dependencies are satisfied"
    when :install then
      gemfile = options[:gemfile] || 'Gemfile'

      request_set = Gem::RequestSet.new
      request_set.install_from_gemdeps gemdeps: gemfile

      @out = ''
    else
      raise "unsupported command stub #{command}"
    end
  end

  def bundled_app *file
    bundled_app = File.join @tmpdir, 'bundled_app'
    FileUtils.mkdir_p bundled_app
    File.join bundled_app, *file
  end

  def double obj
    obj
  end

  def eq actual
    assert_equal actual, @expect
  end

  def err
    @err
  end

  def exist
  end

  def expect object = nil, &block
    @expect = block || object
  end

  def generic a
  end

  def gem_repo1
    File.join @tmpdir, 'repo', ''
  end

  def gem_repo2
    File.join @tmpdir, 'repo', ''
  end

  def gemfile file = bundled_app('Gemfile'), contents
    File.write file, contents
  end

  def in_app_root &block
    Dir.chdir bundled_app, &block
  end

  def include object
    assert_includes @expect, object
  end

  def install_gemfile content, b = nil
    File.write 'Gemfile', content

    request_set = Gem::RequestSet.new

    e = nil

    @out, @err = capture_io do
      begin
        request_set.install_from_gemdeps gemdeps: 'Gemfile'
      rescue => e
      end
    end

    @out << "\n#{e.message}" if e
    @out << "\n#{@err}" unless @err.empty?
  end

  def lib_path a
  end

  def local
  end

  def lockfile a
  end

  def lockfile_should_be content
    lockfile_content = File.read 'Gemfile.lock'

    assert_equal content, lockfile_content
  end

  def match pattern
    assert_match pattern, @expect
  end

  def not_local
  end

  def not_local_tag
  end

  def out
    @out
  end

  def raise_error exception_class, message
    e = assert_raises exception_class, &@expect

    assert_match message, e.message
  end

  def receive method
    @receive = method

    self
  end

  def revision_for a
  end

  def run cmd
    return super if MiniTest::Unit === cmd

    r, w = IO.pipe

    Process.spawn Gem.ruby, '-e', cmd, out: w
    w.close

    @out = r.read.strip
  end

  def should_be_installed specifier, b = nil
    name, version = specifier.split ' ', 2
    version = Gem::Version.new version

    assert Gem::Specification.find_by_name name, version
  end

  def should_not_be_installed a
  end

  def simulate_bundler_version a
  end

  def simulate_platform a
  end

  def subject
    @subject ||= subject_class.new
  end

  def subject_class
    self.class.instance_variable_get :@subject_class
  end

  def tmp
    @tmpdir
  end

  def update_git a, b
  end

  def with a
    self
  end

  ############################################################################
  # Gem::TestCase copy and paste
  ############################################################################

  ##
  # Creates a Gem::Specification with a minimum of extra work.  +name+ and
  # +version+ are the gem's name and version,  platform, author, email,
  # homepage, summary and description are defaulted.  The specification is
  # yielded for customization.
  #
  # The gem is added to the installed gems in +@gemhome+ and the runtime.
  #
  # Use this with #write_file to build an installed gem.

  def quick_gem(name, version='2')
    require 'rubygems/specification'

    spec = Gem::Specification.new do |s|
      s.platform    = Gem::Platform::RUBY
      s.name        = name
      s.version     = version
      s.author      = 'A User'
      s.email       = 'example@example.com'
      s.homepage    = 'http://example.com'
      s.summary     = "this is a summary"
      s.description = "This is a test description"

      yield(s) if block_given?
    end

    Gem::Specification.map # HACK: force specs to (re-)load before we write

    written_path = write_file spec.spec_file do |io|
      io.write spec.to_ruby_for_cache
    end

    spec.loaded_from = spec.loaded_from = written_path

    Gem::Specification.add_spec spec.for_cache

    return spec
  end

  ##
  # Creates a SpecFetcher pre-filled with the gems or specs defined in the
  # block.
  #
  # Yields a +fetcher+ object that responds to +spec+ and +gem+.  +spec+ adds
  # a specification to the SpecFetcher while +gem+ adds both a specification
  # and the gem data to the RemoteFetcher so the built gem can be downloaded.
  #
  # If only the a-3 gem is supposed to be downloaded you can save setup
  # time by creating only specs for the other versions:
  #
  #   spec_fetcher do |fetcher|
  #     fetcher.spec 'a', 1
  #     fetcher.spec 'a', 2, 'b' => 3 # dependency on b = 3
  #     fetcher.gem 'a', 3 do |spec|
  #       # spec is a Gem::Specification
  #       # ...
  #     end
  #   end

  def spec_fetcher repository = @gem_repo
    Gem::TestCase::SpecFetcherSetup.declare self, repository do |spec_fetcher_setup|
      yield spec_fetcher_setup if block_given?
    end
  end

  ##
  # Builds a gem from +spec+ and places it in <tt>File.join @gemhome,
  # 'cache'</tt>.  Automatically creates files based on +spec.files+

  def util_build_gem spec
    dir = spec.gem_dir
    FileUtils.mkdir_p dir

    Dir.chdir dir do
      spec.files.each do |file|
        next if File.exist? file
        FileUtils.mkdir_p File.dirname(file)
        File.open file, 'w' do |fp| fp.puts "# #{file}" end
      end

      use_ui Gem::MockGemUi.new do
        Gem::Package.build spec
      end

      cache = spec.cache_file
      FileUtils.mkdir_p File.dirname cache
      FileUtils.mv File.basename(cache), cache
    end
  end

  ##
  # Creates a gem with +name+, +version+ and +deps+.  The specification will
  # be yielded before gem creation for customization.  The gem will be placed
  # in <tt>File.join @tmpdir, 'gems'</tt>.  The specification and .gem file
  # location are returned.

  def util_gem name, version, deps = nil, &block
    raise "deps or block, not both" if deps and block

    if deps then
      block = proc do |s|
        # Since Hash#each is unordered in 1.8, sort
        # the keys and iterate that way so the tests are
        # deterministic on all implementations.
        deps.keys.sort.each do |n|
          s.add_dependency n, (deps[n] || '>= 0')
        end
      end
    end

    spec = quick_gem(name, version, &block)

    util_build_gem spec

    cache_file = File.join @tmpdir, 'gems', "#{spec.original_name}.gem"
    FileUtils.mkdir_p File.dirname cache_file
    FileUtils.mv spec.cache_file, cache_file
    FileUtils.rm spec.spec_file

    spec.loaded_from = nil

    [spec, cache_file]
  end

  ##
  # Gzips +data+.

  def util_gzip(data)
    out = StringIO.new

    Zlib::GzipWriter.wrap out do |io|
      io.write data
    end

    out.string
  end

  ##
  # Sets up Gem::SpecFetcher to return information from the gems in +specs+.
  # Best used with +@all_gems+ from #util_setup_fake_fetcher.

  def util_setup_spec_fetcher *specs
    specs -= Gem::Specification._all
    Gem::Specification.add_specs(*specs)

    spec_fetcher = Gem::SpecFetcher.fetcher

    prerelease, all = Gem::Specification.partition { |spec|
      spec.version.prerelease?
    }

    spec_fetcher.specs[@uri] = []
    all.each do |spec|
      spec_fetcher.specs[@uri] << spec.name_tuple
    end

    spec_fetcher.latest_specs[@uri] = []
    Gem::Specification.latest_specs.each do |spec|
      spec_fetcher.latest_specs[@uri] << spec.name_tuple
    end

    spec_fetcher.prerelease_specs[@uri] = []
    prerelease.each do |spec|
      spec_fetcher.prerelease_specs[@uri] << spec.name_tuple
    end

    # HACK for test_download_to_cache
    unless Gem::RemoteFetcher === @fetcher then
      v = Gem.marshal_version

      specs = all.map { |spec| spec.name_tuple }
      s_zip = util_gzip Marshal.dump Gem::NameTuple.to_basic specs

      latest_specs = Gem::Specification.latest_specs.map do |spec|
        spec.name_tuple
      end

      l_zip = util_gzip Marshal.dump Gem::NameTuple.to_basic latest_specs

      prerelease_specs = prerelease.map { |spec| spec.name_tuple }
      p_zip = util_gzip Marshal.dump Gem::NameTuple.to_basic prerelease_specs

      @fetcher.data["#{@gem_repo}specs.#{v}.gz"]            = s_zip
      @fetcher.data["#{@gem_repo}latest_specs.#{v}.gz"]     = l_zip
      @fetcher.data["#{@gem_repo}prerelease_specs.#{v}.gz"] = p_zip

      v = Gem.marshal_version

      Gem::Specification.each do |spec|
        path = "#{@gem_repo}quick/Marshal.#{v}/#{spec.original_name}.gemspec.rz"
        data = Marshal.dump spec
        data_deflate = Zlib::Deflate.deflate data
        @fetcher.data[path] = data_deflate
      end
    end

    nil # force errors
  end

  ##
  # Writes a binary file to +path+ which is relative to +@gemhome+

  def write_file path
    path = File.join @gemhome, path unless Pathname.new(path).absolute?
    dir = File.dirname path
    FileUtils.mkdir_p dir

    open path, 'wb' do |io|
      yield io if block_given?
    end

    path
  end

end

class String
  def info_signal
  end

  def record
  end
end

module SpecOverrides
  def describe subject_class
    spec = super

    unless Class === subject_class then
      subject_class = MiniTest::Spec.describe_stack.each { |klass|
        if desc = klass.instance_variable_get(:@desc) then
          break desc
        end
      }
    end

    spec.instance_variable_set :@subject_class, subject_class

    spec
  end

  alias context describe
end

class Object
  include SpecOverrides

  def to a
  end
end

MiniTest::Spec.include Bundler::GemHelpers
