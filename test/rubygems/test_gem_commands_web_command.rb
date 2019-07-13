# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/executor'
require 'rubygems/commands/web_command'

class TestGemCommandsWebCommand < Gem::TestCase

  def setup
    super
    @cmd = Gem::Commands::WebCommand.new
    @mock = MiniTest::Mock.new
  end

  def test_open_browser_command
    @mock.expect(:os, "darwin")
    @mock.expect(:version, '')

    Gem::Platform.stub :local, @mock do
      open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                 Gem::Platform.local.version,
                                                                 "http://github.com/ruby/ruby")
      assert_match /open/, open_browser_cmd
    end

    @mock.verify
  end

  def test_default_option
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                       Gem::Platform.local.version,
                                                                       "http://github.com/rails/rails")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_the_documentation
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                       Gem::Platform.local.version,
                                                                       "http://api.rubyonrails.org")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-d rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_the_homepage
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                    Gem::Platform.local.version,
                                                                    "http://rubyonrails.org")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-w rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_the_source_code
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                       Gem::Platform.local.version,
                                                                       "http://github.com/rails/rails")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-c rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_github
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                       Gem::Platform.local.version,
                                                                       "http://github.com/rails/rails")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-g rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_rubygems
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                       Gem::Platform.local.version,
                                                                       "https://rubygems.org/gems/rails")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-r rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_rubytoolbox
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                    Gem::Platform.local.version,
                                                                    "https://www.ruby-toolbox.com/projects/rails")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-t rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_search_unexisting_gem
    gem = "this-is-an-unexisting-gem"
    assert_output(/Did not find #{gem} on rubygems.org\n/) do
      @cmd.handle_options [gem]
      @cmd.execute
    end
  end

  def test_open_rubygems_if_it_could_not_find_page
    open_browser_cmd = Gem::Web::Executor.new.open_default_browser_cmd(Gem::Platform.local.os,
                                                                       Gem::Platform.local.version,
                                                                       "https://rubygems.org/gems/rails")
    @mock.expect(:call, true, [open_browser_cmd])

    @cmd.executor.stub :system, @mock do
      assert_output("Did not find page for rails, opening RubyGems page instead.\n") do
        @cmd.executor.launch_browser("rails", "")
      end
    end

    @mock.verify
  end

  def test_unsupported_platform
    @mock.expect(:os, "unsupported_os")
    @mock.expect(:version, "")

    Gem::Platform.stub :local, @mock do
      assert_output("The command 'web' is not supported on your platform.\n") do
        @cmd.handle_options %w[-r rails]
        @cmd.execute
      end
    end

    @mock.verify
  end

end
