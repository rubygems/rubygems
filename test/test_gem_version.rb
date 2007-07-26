require 'test/unit'
require 'test/gemutilities'
require 'rubygems/version'

class TestGemVersion < RubyGemTestCase

  def setup
    super

    @version = Gem::Version.new '1.0'
  end

  def test_class_create
    assert_version Gem::Version.create('1.0')
    assert_version Gem::Version.create("1.0 ")
    assert_version Gem::Version.create(" 1.0 ")
    assert_version Gem::Version.create("1.0\n")
    assert_version Gem::Version.create("\n1.0\n")
  end

  def test_class_create_malformed
    e = assert_raise ArgumentError do Gem::Version.create("junk") end
    assert_equal "Malformed version number string junk", e.message

    e = assert_raise ArgumentError do Gem::Version.create("1.0\n2.0") end
    assert_equal "Malformed version number string 1.0\n2.0", e.message
  end

  def assert_version(actual)
    assert_equal @version, actual
    assert_equal @version.version, actual.version
  end

end

