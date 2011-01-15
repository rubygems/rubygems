require File.expand_path('../gemutilities', __FILE__)
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

