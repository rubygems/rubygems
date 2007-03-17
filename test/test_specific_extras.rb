#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++


require 'test/unit'
require 'rubygems/command_manager'
require 'rubygems/user_interaction'
require 'test/mockgemui'

class TestSpecificExtras < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @cm = Gem::CommandManager.new
    @cmd = @cm['rdoc']
  end

  
  def test_add_extra_args
    added_args = ["--all"]
    command = "rdoc"
    Gem::Command.add_specific_extra_args command, added_args

    assert_equal(added_args, Gem::Command.specific_extra_args(command))

    Gem::Command.instance_eval "public :add_extra_args"
    h = @cmd.add_extra_args([])
    assert_equal(added_args,h)
  end
  
  def test_add_extra_args_unknown
    added_args = ["--definitely_not_there"]
    command = "rdoc"
    Gem::Command.add_specific_extra_args command, added_args

    assert_equal(added_args, Gem::Command.specific_extra_args(command))

    Gem::Command.instance_eval "public :add_extra_args"
    h = @cmd.add_extra_args([])
    assert_equal([],h)
  end
end
