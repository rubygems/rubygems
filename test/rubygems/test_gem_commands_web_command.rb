# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/executor'
require 'rubygems/commands/web_command'

class TestGemCommandsWebCommand < Gem::TestCase

  def setup
    super
    @cmd = Gem::Commands::WebCommand.new
    @mock = MiniTest::Mock.new
    ENV['BROWSER'] = nil
    @gem = "rails"
    response = <<~HEREDOC
      {
        "source_code_uri": "http://github.com/rails/rails",
        "documentation_uri": "http://api.rubyonrails.org",
        "homepage_uri": "http://rubyonrails.org"
      }
    HEREDOC

    @mock.expect(:read, response)
  end

  def test_default_option
    OpenURI.stub :open_uri, @mock do
      assert_output("http://github.com/rails/rails\n") do
        @cmd.handle_options [@gem]
        @cmd.execute
      end
    end
    @mock.verify
  end

  def test_open_the_documentation
    OpenURI.stub :open_uri, @mock do
      assert_output("http://api.rubyonrails.org\n") do
        @cmd.handle_options ["-d", @gem]
        @cmd.execute
      end
    end
  end

  def test_open_the_homepage
    OpenURI.stub :open_uri, @mock do
      assert_output("http://rubyonrails.org\n") do
        @cmd.handle_options ["-w", @gem]
        @cmd.execute
      end
    end
  end

  def test_open_the_source_code
    OpenURI.stub :open_uri, @mock do
      assert_output("http://github.com/rails/rails\n") do
        @cmd.handle_options ["-c", @gem]
        @cmd.execute
      end
    end
  end

  def test_open_github
    OpenURI.stub :open_uri, @mock do
      assert_output("http://github.com/rails/rails\n") do
        @cmd.handle_options ["-g", @gem]
        @cmd.execute
      end
    end
  end

  def test_open_rubygems
    OpenURI.stub :open_uri, @mock do
      assert_output("https://rubygems.org/gems/rails\n") do
        @cmd.handle_options ["-r", @gem]
        @cmd.execute
      end
    end
  end

  def test_open_rubytoolbox
    OpenURI.stub :open_uri, @mock do
      assert_output("https://www.ruby-toolbox.com/projects/rails\n") do
        @cmd.handle_options ["-t", @gem]
        @cmd.execute
      end
    end
  end

  def test_search_unexisting_gem
    raises_exception = proc { raise OpenURI::HTTPError.new("error", nil) }

    OpenURI.stub :open_uri, raises_exception do
      gem = "this-is-an-unexisting-gem"
      assert_output(/Did not find #{gem} on rubygems.org\n/) do
        @cmd.handle_options [gem]
        @cmd.execute
      end
    end
  end

  def test_open_rubygems_if_it_could_not_find_page
    OpenURI.stub :open_uri, @mock do
      out, _ = capture_io do
        @cmd.executor.launch_browser("rails", "")
      end
      assert_match(/Did not find page for rails, opening RubyGems page instead./, out)
      assert_match(/https:\/\/rubygems.org\/gems\/rails/, out)
    end
  end

  def test_open_browser_if_env_variable_is_set
    OpenURI.stub :open_uri, @mock do
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

end
