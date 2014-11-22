require 'rubygems/test_case'
require 'rubygems/remote_fetcher_cache'
require 'fileutils'

class TestGemRemoteFetcherCache < Gem::TestCase

  def setup
    super
    @fetcher = Gem::RemoteFetcherCache.new
  end

  def test_escapes_windows_paths
    uri = URI.parse("file:///C:/WINDOWS/Temp/gem_repo")
    root = @fetcher.fetch_cache_dir
    cache_path = @fetcher.cache_path_for(uri).gsub(root, '')
    assert cache_path !~ /:/, "#{cache_path} should not contain a :"
  end

end
