require 'test/unit'
$:.unshift '../lib'
require 'rubygems'
require 'test/mockgemui'
Gem::manage_gems

class TestParseCommands < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup
    @cmd_manager = Gem::CommandManager.new
  end

  def test_parsing_bad_options
    use_ui(MockGemUi.new) do
      @cmd_manager.process_args("--bad-arg")
      assert_match /invalid option: --bad-arg/, ui.error
    end
  end

  def test_parsing_install_options
    #capture all install options
    use_ui(MockGemUi.new) do
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
      check_options = nil
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
      check_options = nil
      @cmd_manager.process_args("install --remote")
      assert_equal check_options[:domain], :remote
      
      #check both domain
      check_options = nil
      @cmd_manager.process_args("install --both")
      assert_equal check_options[:domain], :both
      
      #check both domain
      check_options = nil
      @cmd_manager.process_args("install --both")
      assert_equal check_options[:domain], :both
    end
  end
  
  def test_parsing_uninstall_options
    #capture all uninstall options
    check_options = nil
    @cmd_manager['uninstall'].when_invoked do |options|
      check_options = options
      true
    end
    
    #check defaults
    @cmd_manager.process_args("uninstall")
    assert_equal check_options[:version], "> 0"

    #check settings
    check_options = nil
    @cmd_manager.process_args("uninstall --name foobar --version 3.0")
    assert_equal check_options[:name], "foobar"
    assert_equal check_options[:version], "3.0"
  end

  def test_parsing_check_options
    #capture all check options
    check_options = nil
    @cmd_manager['check'].when_invoked do |options|
      check_options = options
      true
    end
    
    #check defaults
    @cmd_manager.process_args("check")
    assert_equal check_options[:verify], false
    assert_equal check_options[:alien], false

    #check settings
    check_options = nil
    @cmd_manager.process_args("check --verify foobar --alien")
    assert_equal check_options[:verify], "foobar"
    assert_equal check_options[:alien], true
  end
    
  def test_parsing_build_options
    #capture all build options
    check_options = nil
    @cmd_manager['build'].when_invoked do |options|
      check_options = options
      true
    end
    
    #check defaults
    @cmd_manager.process_args("build")
    #NOTE: Currently no defaults
    
    #check settings
    check_options = nil
    @cmd_manager.process_args("build --name foobar.rb")
    assert_equal check_options[:name], 'foobar.rb'
  end
  
  def test_parsing_query_options
    #capture all query options
    check_options = nil
    @cmd_manager['query'].when_invoked do |options|
      check_options = options
      true
    end
    
    #check defaults
    @cmd_manager.process_args("query")
    assert_equal check_options[:name], /.*/
    assert_equal check_options[:domain], :local
    assert_equal check_options[:details], false
    
    #check settings
    check_options = nil
    @cmd_manager.process_args("query --name foobar --local --details")
    assert_equal check_options[:name], /foobar/
    assert_equal check_options[:domain], :local
    assert_equal check_options[:details], true

    #remote domain
    check_options = nil
    @cmd_manager.process_args("query --remote")
    assert_equal check_options[:domain], :remote

    #both (local/remote) domains
    check_options = nil
    @cmd_manager.process_args("query --both")
    assert_equal check_options[:domain], :both
  end  
  
  def test_parsing_update_options
    #capture all update options
    check_options = nil
    @cmd_manager['update'].when_invoked do |options|
      check_options = options
      true
    end
    
    #check defaults
    @cmd_manager.process_args("update")
    assert_equal check_options[:stub], true
    assert_equal check_options[:generate_rdoc], false
    
    #check settings
    check_options = nil
    @cmd_manager.process_args("update --force --test --no-install-stub --gen-rdoc --install-dir .")
    assert_equal check_options[:stub], false
    assert_equal check_options[:test], true
    assert_equal check_options[:generate_rdoc], true
    assert_equal check_options[:force], true
    assert_equal check_options[:install_dir], '.'
  end 
  
end
