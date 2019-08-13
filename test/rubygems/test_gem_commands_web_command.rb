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
    [["-c", "source_code_uri"], ["-d", "documentation_uri"]].each do |test_case|
      option = test_case[0]
      info = test_case[1]
      @mock.expect(:metadata, {})
      @mock.expect(:name, @gem)

      Gem::Specification.stub :find_by_name, @mock do
        assert_output("Gem '#{@gem}' does not specify #{info}.\n") do
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

  def test_search_online_if_gem_is_not_installed
    gem = "this-is-an-unexisting-gem"
    exception = proc { raise Gem::MissingSpecError.new("error", nil) }
    spec = MiniTest::Mock.new
    spec.expect(:homepage, "https://bestgemever.example.io")
    spec.expect(:nil?, false)

    Gem::Specification.stub :find_by_name, exception do
      @cmd.executor.stub :fetch_remote_spec, spec do
        assert_output("https://bestgemever.example.io\n") do
          @cmd.handle_options [gem]
          @cmd.execute
        end
      end
    end

    spec.verify
  end

  def test_search_online_for_inexisting_gem
    gem = "this-is-an-unexisting-gem"
    exception = proc { raise Gem::MissingSpecError.new("error", nil) }

    Gem::Specification.stub :find_by_name, exception, [gem] do
      @cmd.executor.stub :fetch_remote_spec, nil do
        assert_output(/Could not find '#{gem}' in rubygems.org too./) do
          @cmd.handle_options [gem]
          @cmd.execute
        end
      end
    end
  end

  def test_fetch_remote_spec
    found_spec = [[[util_spec(@gem), "sources"]], []]

    Gem::SpecFetcher.fetcher.stub :spec_for_dependency, found_spec do
      spec = @cmd.executor.fetch_remote_spec @gem
      assert_equal @gem, spec.name
    end
  end

  def test_fetch_unexisting_remote_spec
    gem = "this-is-an-unexisting-gem"
    not_found = [[], []]

    Gem::SpecFetcher.fetcher.stub :spec_for_dependency, not_found do
      assert_nil @cmd.executor.fetch_remote_spec gem
    end
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
        @cmd.executor.open_browser(uri)
      end
    end

    browser_mock.verify
    env_mock.verify
  end

end
