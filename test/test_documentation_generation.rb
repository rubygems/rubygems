#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'rubygems'
Gem::manage_gems
require 'flexmock'
require 'flexmock/test_unit'
require 'test/simple_gem'

class TestDocumentationGeneration < Test::Unit::TestCase
  def setup
    @spec = Gem::Specification.new do |s|
      s.files = ['lib/code.rb','lib/apple.rb','lib/brown.rb']
      s.name = "a"
      s.version = "0.0.1"
      s.summary = "summary"
      s.description = "desc"
      s.require_path = 'lib'
      s.loaded_from = '/tmp/foo/bar'
    end    
    @manager = Gem::DocManager.new(@spec)
  end
  
  
  def test_unwritable_destination_path_throws_file_permission_error
    flexmock(File).should_receive(:writable?).and_return(false)    
    assert_raises(Gem::FilePermissionError) do
      Gem::DocManager.new(@spec)
    end
  end
  
end