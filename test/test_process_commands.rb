#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
$:.unshift '../lib'
require 'rubygems'
Gem::manage_gems

require 'test/mockgemui'

class InterruptCommand < Gem::Command

  def initialize
    super('interrupt', 'Raises an Interrupt Exception', {})
  end

  def execute
    raise Interrupt, "Interrupt exception"
  end

end

class TestProcessCommands < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @command_manager = Gem::CommandManager.new
  end

  def test_query_command
    use_ui(MockGemUi.new) do
      @command_manager.process_args "query"
      assert_match(/LOCAL GEMS/, ui.output)
    end
  end

  def test_run_interrupt
    use_ui(MockGemUi.new) do
      @command_manager.register_command :interrupt
      assert_raises MockGemUi::TermError do
        @command_manager.run 'interrupt'
      end
      assert_equal '', ui.output
      assert_equal "ERROR:  Interrupted\n", ui.error
    end
  end

end

