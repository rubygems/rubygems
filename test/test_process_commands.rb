#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rubygems/command'
require 'rubygems/command_manager'

class InterruptCommand < Gem::Command

  def initialize
    super('interrupt', 'Raises an Interrupt Exception', {})
  end

  def execute
    raise Interrupt, "Interrupt exception"
  end

end

class TestProcessCommands < RubyGemTestCase
  include Gem::DefaultUserInteraction

  def setup
    super

    @command_manager = Gem::CommandManager.new
  end

  def test_query_command
    use_ui @ui do
      @command_manager.process_args "query"
      assert_match(/LOCAL GEMS/, ui.output)
    end
  end

  def test_run_interrupt
    use_ui @ui do
      @command_manager.register_command :interrupt
      assert_raises MockGemUi::TermError do
        @command_manager.run 'interrupt'
      end
      assert_equal '', ui.output
      assert_equal "ERROR:  Interrupted\n", ui.error
    end
  end

end

