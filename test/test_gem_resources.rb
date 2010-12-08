require File.expand_path('../gemutilities', __FILE__)
require 'rubygems/resources'

class TestGemSpecification < RubyGemTestCase

  def test_resource_new_empty
    Gem::Resources.new
  end

  def test_resource_new_with_entries
    Gem::Resources.new(:wiki=>'http://someplace.org')
  end

  def test_add_resource
    r = Gem::Resources.new
    r.add_resource('home', 'http://someplace.org')
    assert_equal 'http://someplace.org', r.home
    assert_equal 'http://someplace.org', r.homepage
  end

  def test_add_arbitrary_resource
    r = Gem::Resources.new
    r.add_resource('foo', 'http://someplace.org')
    assert_equal 'http://someplace.org', r.foo
  end

  def test_to_h
    r = Gem::Resources.new
    r.add_resource('home', 'http://somehome.org')
    r.add_resource(:wiki, 'http://somewiki.org')
    h = {'home'=>'http://somehome.org',
         'wiki'=>'http://somewiki.org'}
    assert_equal h, r.to_h
  end

  def test_aliases
    r = Gem::Resources.new
    r.add_resource('home', 'http://somehome.org')
    assert_equal r.homepage, 'http://somehome.org'
    r.add_resource('homepage', 'http://someother.org')
    assert_equal r.home, 'http://someother.org'
  end

end
