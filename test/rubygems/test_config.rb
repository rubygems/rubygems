require "test/rubygems/gemutilities"
require 'rubygems'

class TestConfig < RubyGemTestCase

  def test_datadir
    _, err = capture_io do
      datadir = RbConfig::CONFIG['datadir']
      assert_equal "#{datadir}/xyz", RbConfig.datadir('xyz')
    end

    assert_match(/deprecate/, err)
  end

end

