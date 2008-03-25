require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/commands/query_command'

class TestGemCommandsQueryCommand < RubyGemTestCase

  def setup
    super

    util_make_gems

    @a2.summary = 'This is a lot of text. ' * 4

    @cmd = Gem::Commands::QueryCommand.new

    @si = util_setup_source_info_cache @a1, @a2, @pl1
    util_setup_fake_fetcher

    @fetcher.data["#{@gem_repo}/Marshal.#{Gem.marshal_version}"] = proc do
      raise Gem::RemoteFetcher::FetchError
    end
  end

  def test_execute
    cache = Gem::SourceInfoCache.cache
    cache.update
    cache.write_cache
    cache.reset_cache_data

    a2_name = @a2.full_name
    @fetcher.data["#{@gem_repo}/quick/latest_index.rz"] = util_zip a2_name
    @fetcher.data["#{@gem_repo}/quick/Marshal.#{Gem.marshal_version}/#{a2_name}.gemspec.rz"] = util_zip Marshal.dump(@a2)
    @fetcher.data["#{@gem_repo}/Marshal.#{Gem.marshal_version}"] =
      Marshal.dump @si

    @cmd.handle_options %w[-r]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a (2)
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_all
    cache = Gem::SourceInfoCache.cache
    cache.update
    cache.write_cache
    cache.reset_cache_data

    a1_name = @a1.full_name
    a2_name = @a2.full_name
    @fetcher.data["#{@gem_repo}/quick/index.rz"] =
        util_zip [a1_name, a2_name].join("\n")
    @fetcher.data["#{@gem_repo}/quick/latest_index.rz"] = util_zip a2_name
    @fetcher.data["#{@gem_repo}/quick/Marshal.#{Gem.marshal_version}/#{a1_name}.gemspec.rz"] = util_zip Marshal.dump(@a1)
    @fetcher.data["#{@gem_repo}/quick/Marshal.#{Gem.marshal_version}/#{a2_name}.gemspec.rz"] = util_zip Marshal.dump(@a2)
    @fetcher.data["#{@gem_repo}/Marshal.#{Gem.marshal_version}"] =
      Marshal.dump @si

    @cmd.handle_options %w[-r --all]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

Updating metadata for 1 gems from http://gems.example.com/
.
complete
a (2, 1)
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_details
    @cmd.handle_options %w[-r -d]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a (2, 1)
    This is a lot of text. This is a lot of text. This is a lot of text.
    This is a lot of text.

pl (1)
    this is a summary
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_no_versions
    @cmd.handle_options %w[-r --no-versions]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a
pl
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

end

