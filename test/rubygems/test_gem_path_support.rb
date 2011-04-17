require 'rubygems/test_case'
require 'rubygems'
require 'rubygems/fs'
require 'fileutils'

class TestGemPathSupport < Gem::TestCase
  def setup
    super

    ENV["GEM_HOME"] = @tempdir
    ENV["GEM_PATH"] = [@tempdir, "something"].join(File::PATH_SEPARATOR)
  end

  def test_initialize
    ps = Gem::PathSupport.new

    assert_equal ENV, ps.env
    assert_equal Gem::Path.new(ENV["GEM_HOME"]), ps.home

    expected = util_path
    assert_equal expected, ps.path, "defaults to GEM_PATH"
  end

  def test_initialize_home
    ps = Gem::PathSupport.new "GEM_HOME" => "#{@tempdir}/foo"

    refute_equal ENV, ps.env
    assert_equal Gem::Path.new(@tempdir, "foo"), ps.home

    expected = util_path + [Gem::Path.new(@tempdir, 'foo')]
    assert_equal expected, ps.path
  end

  def test_initialize_path
    ps = Gem::PathSupport.new "GEM_PATH" => %W[#{@tempdir}/foo #{@tempdir}/bar]

    refute_equal ENV, ps.env
    assert_equal Gem::Path.new(ENV["GEM_HOME"]), ps.home

    expected = [
                Gem::Path.new(@tempdir, 'foo'),
                Gem::Path.new(@tempdir, 'bar'),
                Gem::Path.new(ENV["GEM_HOME"])
               ]

    assert_equal expected, ps.path
  end

  def test_initialize_home_path
    ps = Gem::PathSupport.new("GEM_HOME" => "#{@tempdir}/foo",
                              "GEM_PATH" => %W[#{@tempdir}/foo #{@tempdir}/bar])

    refute_equal ENV, ps.env
    assert_equal Gem::Path.new(@tempdir, "foo"), ps.home

    expected = [Gem::Path.new(@tempdir, 'foo'), Gem::Path.new(@tempdir, 'bar')]
    assert_equal expected, ps.path
  end

  def util_path
    ENV["GEM_PATH"].split(File::PATH_SEPARATOR).map { |x|
      Gem::Path.new x
    }
  end
end
