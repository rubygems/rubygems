#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems/cmd_manager'
require 'rubygems/user_interaction'
require 'test/mockgemui'

class TestCheckCommand < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @cm = Gem::CommandManager.instance
    @cmd = @cm['check']
  end

  def test_create
    assert_equal "check", @cmd.command
    assert_equal "gem check", @cmd.program_name
    assert_match /Check/, @cmd.summary
  end

  def test_invoke_help
    use_ui(MockGemUi.new) do 
      assert ! @cmd.invoke('--help')
      assert_match /Usage:/, ui.output
    end
  end
end
