require 'test/unit'
$:.unshift '../lib'
require 'rubygems'
Gem::manage_gems

require 'test/mockgemui'

class TestProcessCommands < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @cmd_manager = Gem::CommandManager.instance
  end

  def test_install_command
    use_ui(MockGemUi.new) do
      @cmd_manager.process_args "install"
      assert_match /specify a gem name/, ui.error
    end
  end

  def test_query_command
    use_ui(MockGemUi.new) do
      @cmd_manager.process_args "query"
      puts ui.output
    end
  end
  
  
end
