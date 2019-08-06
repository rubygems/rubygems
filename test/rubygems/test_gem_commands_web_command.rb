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
    @gem = "bestgemever"
  end

  def test_default_option_should_be_homepage
    @mock.expect(:homepage, "https://bestgemever.example.io")
    Gem::Specification.stub :find_by_name, @mock do
      assert_output("https://bestgemever.example.io\n") do
        @cmd.handle_options [@gem]
        @cmd.execute
      end
    end
    @mock.verify
  end

  def test_open_the_documentation
    metadata = {
      "documentation_uri" => "https://www.example.info/gems/bestgemever/0.0.1",
    }
    @mock.expect(:metadata, metadata)

    Gem::Specification.stub :find_by_name, @mock do
      assert_output("https://www.example.info/gems/bestgemever/0.0.1\n") do
        @cmd.handle_options ["-d", @gem]
        @cmd.execute
      end
    end
    @mock.verify
  end

  def test_open_the_homepage
    @mock.expect(:homepage, "https://bestgemever.example.io")

    Gem::Specification.stub :find_by_name, @mock do
      assert_output("https://bestgemever.example.io\n") do
        @cmd.handle_options ["-w", @gem]
        @cmd.execute
      end
    end
    @mock.verify
  end

  def test_open_the_source_code
    metadata = {
      "source_code_uri" => "https://example.com/user/bestgemever"
    }
    @mock.expect(:metadata, metadata)

    Gem::Specification.stub :find_by_name, @mock do
      assert_output("https://example.com/user/bestgemever\n") do
        @cmd.handle_options ["-c", @gem]
        @cmd.execute
      end
    end
    @mock.verify
  end

  def test_open_when_info_is_missing
    ["-c", "-d"].each do |option|
      @mock.expect(:metadata, {})
      Gem::Specification.stub :find_by_name, @mock do
        assert_output("This gem does not have this information.\n") do
          @cmd.handle_options [option, @gem]
          @cmd.execute
        end
      end
      @mock.verify
    end
  end

  def test_open_rubygems
    Gem::Specification.stub :find_by_name, @mock do
      assert_output("https://rubygems.org/gems/#{@gem}\n") do
        @cmd.handle_options ["-r", @gem]
        @cmd.execute
      end
    end
    @mock.verify
  end

  def test_search_unexisting_gem
    gem = "this-is-an-unexisting-gem"
    assert_output(/Could not find '#{gem}'/) do
      @cmd.handle_options [gem]
      @cmd.execute
    end
  end

  # def test_open_rubygems_if_it_could_not_find_page
  #   Gem::Specification.stub :find_by_name, @mock do
  #     out, _ = capture_io do
  #       @cmd.executor.launch_browser("rails", "")
  #     end
  #     assert_match(/Did not find page for rails, opening RubyGems page instead./, out)
  #     assert_match(/https:\/\/rubygems.org\/gems\/rails/, out)
  #   end
  # end

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
