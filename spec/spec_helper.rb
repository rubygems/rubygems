gem 'minitest', '~> 4.0'

require 'minitest/autorun'
require 'minitest/spec'
require 'tmpdir'

require 'rubygems/test_case'

module Kernel
  alias context describe
end

module Bundler
  VERSION = ''
end

module Bundler::GemHelpers

  attr_accessor :fetcher
  attr_accessor :gem_repo
  attr_accessor :uri

  def setup
    super

    @expect   = nil
    @fetcher  = nil
    @gem_repo = 'http://gems.example'
    @uri      = nil

    @tmpdir = Dir.mktmpdir 'rubygems-bundler'

    @pwd = Dir.pwd
    Dir.chdir @tmpdir
  end

  def teardown
    Dir.chdir @pwd
    FileUtils.rm_f @tmpdir
  end

  def build_gem a, b, c = nil
  end

  def build_git a, b = nil
  end

  def build_lib a, b = nil
  end

  def build_repo2
    Gem::TestCase::SpecFetcherSetup.declare self, 'remote2' do |spec_fetcher_setup|
      @spec_fetcher_setup = spec_fetcher_setup
      yield if block_given?
      @spec_fetcher_setup = nil
    end
  end

  def bundle a
  end

  def bundled_app a
  end

  def eq actual
    assert_equal actual, @expect
  end

  def exist
  end

  def expect object
    @expect = object
  end

  def generic a
  end

  def gem_repo1
  end

  def gem_repo2
  end

  def gemfile a
  end

  def include a
  end

  def install_gemfile content, b = nil
    File.write 'Gemfile', content
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

  def match a
  end

  def not_local
  end

  def not_local_tag
  end

  def out
    @out
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

  def should_be_installed a, b = nil
  end

  def should_not_be_installed a
  end

  def simulate_bundler_version a
  end

  def simulate_platform a
  end

  def tmp
  end

  def update_git a, b
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

end

class String
  def info_signal
  end

  def record
  end
end

class Object
  def to a
  end
end

MiniTest::Spec.include Bundler::GemHelpers
