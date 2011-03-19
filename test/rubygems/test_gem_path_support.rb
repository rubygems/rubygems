require 'rubygems/test_case'
require 'rubygems'
require 'rubygems/fs'
require 'fileutils'

class TestGemPathSupport < Gem::TestCase
  def test_constructor
    ENV["GEM_HOME"] = @tempdir
    ENV["GEM_PATH"] = [@tempdir, "something"].join(File::PATH_SEPARATOR)

    ps = Gem::PathSupport.new

    assert_equal ENV, ps.env, "defaults to ENV"
    assert_equal Gem::Path.new(ENV["GEM_HOME"]), ps.home, 
      "defaults to GEM_HOME"

    assert_equal ENV["GEM_PATH"].
                split(File::PATH_SEPARATOR).
                map { |x| Gem::Path.new x },
      ps.path, 
      "defaults to GEM_PATH"

    ps = Gem::PathSupport.new({ :home => "#{@tempdir}/foo" })

    refute_equal ENV, ps.env, "not equal to env when passed a hash"
    assert_equal Gem::Path.new(@tempdir, "foo"), ps.home, 
      "home is the one specified"

    assert_equal ENV["GEM_PATH"].
                split(File::PATH_SEPARATOR).
                map { |x| Gem::Path.new x } + [Gem::Path.new(@tempdir, 'foo')],
      ps.path, 
      "still GEM_PATH, with a proper GEM_HOME"

    ps = Gem::PathSupport.new({ :path => %W[#{@tempdir}/foo #{@tempdir}/bar] })

    refute_equal ENV, ps.env, "not equal to env when passed a hash"
    assert_equal Gem::Path.new(ENV["GEM_HOME"]), ps.home, 
      "when not passed, GEM_HOME"

    assert_equal [
      Gem::Path.new(@tempdir, 'foo'), 
      Gem::Path.new(@tempdir, 'bar'),
      Gem::Path.new(ENV["GEM_HOME"])
    ], ps.path, "when passed, is the path specified + GEM_HOME"
  end
end
