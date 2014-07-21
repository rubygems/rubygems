gem 'minitest', '~> 4.0'

require 'minitest/autorun'
require 'minitest/spec'
require 'tmpdir'

module Kernel
  alias context describe
end

module Bundler
  VERSION = ''
end

module Bundler::GemHelpers

  def setup
    super

    @expect = nil

    @tmpdir = Dir.mktmpdir 'rubygems-bundler'

    @pwd = Dir.pwd
    Dir.chdir @tmpdir
  end

  def teardown
    Dir.chdir @pwd
    FileUtils.rm_f @tmpdir
  end

  def build_gem a, b, c
  end

  def build_git a, b = nil
  end

  def build_lib a, b = nil
  end

  def build_repo2
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
    open 'Gemfile', 'w' do |io|
      io.write content
    end
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
  end

  def revision_for a
  end

  def run a
    return super if MiniTest::Unit === a
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

end

class String
  def info_signal
  end

  def record
  end
end

class NilClass
  def to a
  end
end

MiniTest::Spec.include Bundler::GemHelpers
