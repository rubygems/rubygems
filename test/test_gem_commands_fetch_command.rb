require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/package'
require 'rubygems/security'
require 'rubygems/commands/fetch_command'

class TestGemCommandsFetchCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::FetchCommand.new
  end

  def test_execute
    util_setup_fake_fetcher
    util_setup_spec_fetcher @a2

    @fetcher.data["#{@gem_repo}gems/#{@a2.file_name}"] =
      File.read(File.join(@gemhome, 'cache', @a2.file_name))

    @cmd.options[:args] = [@a2.name]

    use_ui @ui do
      Dir.chdir @tempdir do
        @cmd.execute
      end
    end

    assert File.exist?(File.join(@tempdir, @a2.file_name)),
           "#{@a2.full_name} fetched"
  end

end

