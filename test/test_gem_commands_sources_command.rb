require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/commands/sources_command'

class TestGemCommandsSourcesCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::SourcesCommand.new
  end

  def test_execute
    util_setup_spec_fetcher
    @cmd.handle_options []

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF
*** CURRENT SOURCES ***

#{@gem_repo}
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_add
    util_setup_fake_fetcher

    si = Gem::SourceIndex.new
    si.add_spec @a1

    specs = si.map do |_, spec|
      [spec.name, spec.version, spec.original_platform]
    end

    specs_dump_gz = StringIO.new
    Zlib::GzipWriter.wrap specs_dump_gz do |io|
      Marshal.dump specs, io
    end

    @fetcher.data["http://beta-gems.example.com/specs.#{@marshal_version}.gz"] =
      specs_dump_gz.string

    @cmd.handle_options %w[--add http://beta-gems.example.com]

    util_setup_spec_fetcher

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF
http://beta-gems.example.com added to sources
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_add_nonexistent_source
    util_setup_fake_fetcher

    uri = "http://beta-gems.example.com/specs.#{@marshal_version}.gz"
    @fetcher.data[uri] = proc do
      raise Gem::RemoteFetcher::FetchError.new('it died', uri)
    end

    Gem::RemoteFetcher.fetcher = @fetcher

    @cmd.handle_options %w[--add http://beta-gems.example.com]

    util_setup_spec_fetcher

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF
Error fetching http://beta-gems.example.com:
\tit died (#{uri})
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_add_bad_uri
    @cmd.handle_options %w[--add beta-gems.example.com]

    util_setup_spec_fetcher

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF
beta-gems.example.com is not a URI
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_clear_all
    @cmd.handle_options %w[--clear-all]

    util_setup_spec_fetcher

    fetcher = Gem::SpecFetcher.fetcher

    # HACK figure out how to force directory creation via fetcher
    #assert File.directory?(fetcher.dir), 'cache dir exists'

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF
*** Removed source cache ***
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error

    assert !File.exist?(fetcher.dir), 'cache dir removed'
  end

  def test_execute_remove
    @cmd.handle_options %W[--remove #{@gem_repo}]

    util_setup_spec_fetcher

    use_ui @ui do
      @cmd.execute
    end

    expected = "#{@gem_repo} removed from sources\n"

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_remove_no_network
    @cmd.handle_options %W[--remove #{@gem_repo}]

    util_setup_fake_fetcher

    @fetcher.data["#{@gem_repo}/Marshal.#{Gem.marshal_version}"] = proc do
      raise Gem::RemoteFetcher::FetchError
    end

    use_ui @ui do
      @cmd.execute
    end

    expected = "#{@gem_repo} removed from sources\n"

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

end

