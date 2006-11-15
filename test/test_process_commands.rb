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
    raise Interrupt
  end

end

class TestProcessCommands < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @cmd_manager = Gem::CommandManager.new
  end

  def test_query_command
    use_ui(MockGemUi.new) do
      @cmd_manager.process_args "query"
      assert_match(/LOCAL GEMS/, ui.output)
    end
  end

  def test_run_interrupt
    use_ui(MockGemUi.new) do
      @cmd_manager.register_command InterruptCommand.new
      assert_raises MockGemUi::TermError do
        @cmd_manager.run 'interrupt'
      end
      assert_equal '', ui.output
      assert_equal "ERROR:  Interrupted\n", ui.error
    end
  end

end

