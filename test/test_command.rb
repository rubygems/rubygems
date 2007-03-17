#!/usr/bin/env ruby
#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/mockgemui'

require 'rubygems/command'
require 'rubygems/command_manager'
require 'rubygems/user_interaction'

class Noop
  def method_missing(sym, *args, &block)
  end
end

class TestCommand < Test::Unit::TestCase
  include Gem::DefaultUserInteraction

  def setup 
    @xopt = nil
    Gem::Command.common_options.clear
    Gem::Command.common_options <<  [ ['-x', '--exe', 'Execute'], lambda do @xopt = true end]
    @cmd = Gem::Command.new("doit", "summary")
    self.ui = Noop.new
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
    use_ui(MockGemUi.new) do
      @cmd.when_invoked do true end
      ex = assert_raise(OptionParser::InvalidOption) { @cmd.invoke('-zzz') }
      assert_match(/invalid option:/, ex.message)
    end
  end

  def test_overlapping_common_and_local_options
    use_ui(MockGemUi.new) do
      @cmd.add_option('-x', '--zip', 'BAD!') do end
      @cmd.add_option('-z', '--exe', 'BAD!') do end
      @cmd.add_option('-x', '--exe', 'BAD!') do end
      @cmd.when_invoked do |opts| false end
      @cmd.invoke('-x')
      md = ui.output =~ /Common.*-exe/m
      assert ! @xopt, "Should not do xopt"
      assert_nil md, "Should not have common options"
    end
  end

  # Returning false from the command handler invokes the usage output.
  def test_invoke_with_help
    use_ui(MockGemUi.new) do
      @cmd.add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
        options[:help] = true
      end
      @cmd.invoke('--help')
      assert_match(/Usage/, ui.output)
      assert_match(/gem doit/, ui.output)
      assert_match(/\[options\]/, ui.output)
      assert_match(/-h/, ui.output)
      assert_match(/--help \[COMMAND\]/, ui.output)
      assert_match(/Get help on COMMAND/, ui.output)
      assert_match(/-x/, ui.output)
      assert_match(/--exe/, ui.output)
      assert_match(/Execute/, ui.output)
      assert_match(/Common Options:/, ui.output)
    end
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

  def test_common_option_in_class
    assert Array === Gem::Command.common_options
  end

  def test_option_recognition
    @cmd.add_option('-h', '--help [COMMAND]', 'Get help on COMMAND') do |value, options|
      options[:help] = true
    end
    @cmd.add_option('-f', '--file FILE', 'File option') do |value, options|
      options[:help] = true
    end
    assert @cmd.handles?(['-x'])
    assert @cmd.handles?(['-h'])
    assert @cmd.handles?(['-h', 'command'])
    assert @cmd.handles?(['--help', 'command'])
    assert @cmd.handles?(['-f', 'filename'])
    assert @cmd.handles?(['--file=filename'])
    assert ! @cmd.handles?(['-z'])
    assert ! @cmd.handles?(['-f'])
    assert ! @cmd.handles?(['--toothpaste'])

    args = ['-h', 'command']
    @cmd.handles?(args)
    assert_equal ['-h', 'command'], args
  end
end
