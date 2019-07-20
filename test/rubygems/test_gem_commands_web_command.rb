# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/executor'
require 'rubygems/commands/web_command'

class TestGemCommandsWebCommand < Gem::TestCase

  def setup
    super
    @cmd = Gem::Commands::WebCommand.new
    ENV['BROWSER'] = nil
  end

  def test_default_option
    assert_output("http://github.com/rails/rails\n") do
      @cmd.handle_options %w[rails]
      @cmd.execute
    end
  end

  def test_open_the_documentation
    assert_output("http://api.rubyonrails.org\n") do
      @cmd.handle_options %w[-d rails]
      @cmd.execute
    end
  end

  def test_open_the_homepage
    assert_output("http://rubyonrails.org\n") do
      @cmd.handle_options %w[-w rails]
      @cmd.execute
    end
  end

  def test_open_the_source_code
    assert_output("http://github.com/rails/rails\n") do
      @cmd.handle_options %w[-c rails]
      @cmd.execute
    end
  end

  def test_open_github
    assert_output("http://github.com/rails/rails\n") do
      @cmd.handle_options %w[-g rails]
      @cmd.execute
    end
  end

  def test_open_rubygems
    assert_output("https://rubygems.org/gems/rails\n") do
      @cmd.handle_options %w[-r rails]
      @cmd.execute
    end
  end

  def test_open_rubytoolbox
    assert_output("https://www.ruby-toolbox.com/projects/rails\n") do
      @cmd.handle_options %w[-t rails]
      @cmd.execute
    end
  end

  def test_search_unexisting_gem
    gem = "this-is-an-unexisting-gem"
    assert_output(/Did not find #{gem} on rubygems.org\n/) do
      @cmd.handle_options [gem]
      @cmd.execute
    end
  end

  def test_open_rubygems_if_it_could_not_find_page
    out, _ = capture_io do
      @cmd.executor.launch_browser("rails", "")
    end
    assert_match(/Did not find page for rails, opening RubyGems page instead./, out)
    assert_match(/https:\/\/rubygems.org\/gems\/rails/, out)
  end

  def test_open_browser_if_env_variable_is_set
    open_browser_cmd = "open"
    uri = "http://github.com/rails"

    env_mock = MiniTest::Mock.new
    env_mock.expect(:call, open_browser_cmd, ['BROWSER'])

    browser_mock = MiniTest::Mock.new
    browser_mock.expect(:call, true, [open_browser_cmd, uri])

    ENV.stub :[], env_mock do
      @cmd.executor.stub :system, browser_mock do
        @cmd.executor.open_default_browser(uri)
      end
    end

    browser_mock.verify
    env_mock.verify
  end

end
