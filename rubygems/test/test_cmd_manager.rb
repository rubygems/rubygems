require 'test/unit'
$:.unshift '../lib'
require 'rubygems'
Gem::manage_gems

class TestValidator < Test::Unit::TestCase
  def test_parsing_install_options
    #capture all install options
    check_options = nil
    @cmd_manager['install'].when_invoked do |options|
      check_options = options
      true
    end
 
    #check defaults
    @cmd_manager.process_args("install")
    assert_equal check_options[:stub], true
    assert_equal check_options[:test], false
    assert_equal check_options[:generate_rdoc], false
    assert_equal check_options[:force], false
    assert_equal check_options[:domain], :both
    assert_equal check_options[:version], "> 0"
    assert_equal check_options[:install_dir], Gem.dir
    
    #check settings
    @cmd_manager.process_args("install --force --test --no-install-stub --local --gen-rdoc --name foobar --install-dir . --version 3.0")
    assert_equal check_options[:stub], false
    assert_equal check_options[:test], true
    assert_equal check_options[:generate_rdoc], true
    assert_equal check_options[:force], true
    assert_equal check_options[:domain], :local
    assert_equal check_options[:version], '3.0'
    assert_equal check_options[:name], 'foobar'
    assert_equal check_options[:install_dir], '.'

    #check remote domain
    @cmd_manager.process_args("install --remote")
    assert_equal check_options[:domain], :remote

    #check both domain
    @cmd_manager.process_args("install --both")
    assert_equal check_options[:domain], :both
    
    #check both domain
    @cmd_manager.process_args("install --both")
    assert_equal check_options[:domain], :both
    
    #check bad argument
    error = nil
    @ui.on_alert_error do |message, question|
      error = message
    end
    @cmd_manager.process_args("install --bad-arg")
    assert_match /invalid option: --bad-arg/, error
  end

  def setup
    @ui = Gem::UserInteraction.capture
    @cmd_manager = Gem::CommandManager.instance
  end
end
