require 'test/unit'
$:.unshift '../lib'
require 'rubygems'
Gem::manage_gems

class TestProcessCommands < Test::Unit::TestCase

  def setup
    @ui = Gem::UserInteraction.capture
    @cmd_manager = Gem::CommandManager.instance
  end

  def reset_ui
    @error = ""
    @warning = ""
    @output = ""
    
    @ui.on_alert_warning do |message, question|
      @warning << message.to_s
    end
    
    @ui.on_alert_error do |message, question|
      @error << message.to_s
    end
    
    @ui.on_say do |statement|
      @output << statement.to_s
    end
  end

  
  def test_install_command
    #fail to specify a name
    reset_ui
    @cmd_manager.process_args "install"
    assert_match /specify a gem name/, @error
  end

  def test_query_command
    reset_ui
    @cmd_manager.process_args "query"
    puts @output
  end
  
  
end
