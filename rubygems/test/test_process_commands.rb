require 'test/unit'
$:.unshift '../lib'
require 'rubygems'
Gem::manage_gems

require 'test/mockgemui'

class TestProcessCommands < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @cmd_manager = Gem::CommandManager.new
  end

  def test_query_command
    use_ui(MockGemUi.new) do
      @cmd_manager.process_args "query"
      assert_match /LOCAL GEMS/, ui.output
    end
  end
end
