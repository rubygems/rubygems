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

  def test_default_option
    @mock.expect(:call, true, ["xdg-open", "http://github.com/rails/rails"])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_the_documentation
    @mock.expect(:call, true, ["xdg-open", "http://api.rubyonrails.org"])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-d rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_the_homepage
    @mock.expect(:call, true, ["xdg-open", "http://rubyonrails.org"])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-w rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_the_source_code
    @mock.expect(:call, true, ["xdg-open", "http://github.com/rails/rails"])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-c rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_github
    @mock.expect(:call, true, ["xdg-open", "http://github.com/rails/rails"])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-g rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_rubygems
    @mock.expect(:call, true, ["xdg-open", "https://rubygems.org/gems/rails"])

    @cmd.executor.stub :system, @mock do
      @cmd.handle_options %w[-r rails]
      @cmd.execute
    end

    @mock.verify
  end

  def test_open_rubytoolbox
    @mock.expect(:call, true, ["xdg-open", "https://www.ruby-toolbox.com/projects/rails"])

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
    @mock.expect(:call, true, ["xdg-open", "https://rubygems.org/gems/rails"])

    @cmd.executor.stub :system, @mock do
      assert_output("Did not find page for rails, opening RubyGems page instead.\n") do
        @cmd.executor.launch_browser("rails", "")
      end
    end

    @mock.verify
  end

end
