#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'test/gemutilities'
require 'rubygems/commands/check_command'

class TestCheckCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::CheckCommand.new
  end

  def test_create
    assert_equal "check", @cmd.command
    assert_equal "gem check", @cmd.program_name
    assert_match(/Check/, @cmd.summary)
  end

  def test_invoke_help
    use_ui @ui do 
      assert ! @cmd.invoke('--help')
      assert_match(/Usage:/, ui.output)
    end
  end
end
