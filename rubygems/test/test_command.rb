#!/usr/bin/env ruby

require 'test/unit'
require 'rubygems/command'
require 'rubygems/cmd_manager'
require 'test/user_capture'

class TestCommand < Test::Unit::TestCase
  include UserCapture

  def setup 
    opt_list = [ [ ['-x', '--exe', 'Execute'], lambda do @xopt = true end] ]
    @cmd = Gem::Command.new("doit", "summary", opt_list)
    reset_ui
  end

  def test_basic_accessors
    assert_equal "doit", @cmd.command
    assert_equal "gem doit", @cmd.program_name
    assert_equal "summary", @cmd.summary
  end

  def test_invoke
    done = false
    @cmd.when_invoked { done = true }
    @cmd.invoke
    assert done
  end

  def test_invoke_with_options
    @cmd.add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
      options[:help] = true
    end
    @cmd.when_invoked do |opts|
      assert opts[:help]
      done = true
      true
    end
    @cmd.invoke('-h')
  end

  def test_invoke_with_common_options
    @cmd.when_invoked do true end
    @cmd.invoke("-x")
    assert @xopt, "Should have done xopt"
  end
  
  def test_invode_with_bad_options
    @cmd.when_invoked do true end
    @cmd.invoke('-zzz')
    assert_match /invalid option:/, @error
    assert @terminated, "Should have terminated app"
  end

  def test_overlapping_common_and_local_options
    @cmd.add_option('-x', '--zip', 'BAD!') do end
    @cmd.add_option('-z', '--exe', 'BAD!') do end
    @cmd.add_option('-x', '--exe', 'BAD!') do end
    @cmd.when_invoked do |opts| false end
    @cmd.invoke('-x')
    md = @output =~ /Common.*-exe/m
    assert ! @xopt, "Should not do xopt"
    assert_nil md, "Should not have common options"
  end

  # Returning false from the command handler invokes the usage output.
  def test_invoke_with_help
    @cmd.add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
      options[:help] = true
    end
    @cmd.when_invoked do |opts| false end
    @cmd.invoke
    assert_match /Usage/, @output
    assert_match /gem doit/, @output
    assert_match /\[options\]/, @output
    assert_match /-h/, @output
    assert_match /--help \[COMMAND\]/, @output
    assert_match /Get help on COMMAND/, @output
    assert_match /-x/, @output
    assert_match /--exe/, @output
    assert_match /Execute/, @output
    assert_match /Common Options:/, @output
  end

  def test_defaults
    @cmd.add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
      options[:help] = value
    end
    @cmd.defaults = { :help => true }
    @cmd.when_invoked do |options|
      assert options[:help], "Help options should default true"
    end
    @cmd.invoke 
  end
end
