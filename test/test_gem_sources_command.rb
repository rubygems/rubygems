require 'test/unit'
require 'test/gemutilities'
require 'rubygems/command_manager'

class TestGemSourcesCommand < RubyGemTestCase

  def setup
    super
    Gem::CommandManager.instance # preload command objects
  end

  def test_execute
    util_setup_source_info_cache
    cmd = Gem::Commands::SourcesCommand.new
    cmd.send :handle_options, []

    ui = MockGemUi.new
    use_ui ui do
      cmd.execute
    end

    expected = <<-EOF
*** CURRENT SOURCES ***

http://gems.example.com
    EOF

    assert_equal expected, ui.output
    assert_equal '', ui.error
  end

  def test_execute_add
    util_setup_fake_fetcher

    @si = Gem::SourceIndex.new @gem1.full_name => @gem1.name

    @fetcher.data['http://beta-gems.example.com/yaml'] = @si.to_yaml

    cmd = Gem::Commands::SourcesCommand.new
    cmd.send :handle_options, %w[--add http://beta-gems.example.com]

    util_setup_source_info_cache

    ui = MockGemUi.new
    use_ui ui do
      cmd.execute
    end

    expected = <<-EOF
Bulk updating Gem source index for: http://beta-gems.example.com
http://beta-gems.example.com added to sources
    EOF

    assert_equal expected, ui.output
    assert_equal '', ui.error

    Gem::SourceInfoCache.cache.flush
    assert_equal %w[http://beta-gems.example.com http://gems.example.com],
                 Gem::SourceInfoCache.cache_data.keys
  end

  def test_execute_add_nonexistent_source
    util_setup_fake_fetcher

    @si = Gem::SourceIndex.new @gem1.full_name => @gem1.name

    @fetcher.data['http://beta-gems.example.com/yaml'] = proc do
      raise Gem::RemoteFetcher::FetchError, 'it died'
    end


    Gem::RemoteFetcher.instance_variable_set :@fetcher, @fetcher

    cmd = Gem::Commands::SourcesCommand.new
    cmd.send :handle_options, %w[--add http://beta-gems.example.com]

    util_setup_source_info_cache

    ui = MockGemUi.new
    use_ui ui do
      cmd.execute
    end

    expected = <<-EOF
Error fetching http://beta-gems.example.com:
\tit died
    EOF

    assert_equal expected, ui.output
    assert_equal '', ui.error
  end

  def test_execute_add_bad_uri
    cmd = Gem::Commands::SourcesCommand.new
    cmd.send :handle_options, %w[--add beta-gems.example.com]

    util_setup_source_info_cache

    ui = MockGemUi.new
    use_ui ui do
      cmd.execute
    end

    expected = <<-EOF
beta-gems.example.com is not a URI
    EOF

    assert_equal expected, ui.output
    assert_equal '', ui.error
  end

  def test_execute_remove
    cmd = Gem::Commands::SourcesCommand.new
    cmd.send :handle_options, %w[--remove http://gems.example.com]

    util_setup_source_info_cache

    ui = MockGemUi.new
    use_ui ui do
      cmd.execute
    end

    expected = <<-EOF
http://gems.example.com removed from sources
    EOF

    assert_equal expected, ui.output
    assert_equal '', ui.error

    Gem::SourceInfoCache.cache.flush
    assert_equal [], Gem::SourceInfoCache.cache_data.keys
  end

end

