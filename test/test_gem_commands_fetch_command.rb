require 'test/unit'
require 'test/gemutilities'
require 'rubygems/commands/fetch_command'

class TestGemCommandsFetchCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::FetchCommand.new
  end

  def test_execute
    util_setup_fake_fetcher

    util_build_gem @gem1
    @fetcher.data['http://gems.example.com/yaml'] = @source_index.to_yaml
    @fetcher.data["http://gems.example.com/gems/#{@gem1.full_name}.gem"] =
      File.read(File.join(@gemhome, 'cache', "#{@gem1.full_name}.gem"))

      @cmd.options[:args] = [@gem1.name]

    use_ui @ui do
      Dir.chdir @tempdir do
        @cmd.execute
      end
    end

    assert File.exist?(File.join(@tempdir, "#{@gem1.full_name}.gem"))
  end

end

