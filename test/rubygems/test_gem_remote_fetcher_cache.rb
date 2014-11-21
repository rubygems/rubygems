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

  def test_update_cache_eh
    assert @fetcher.update_cache?
  end

  def test_update_cache_eh_home_nonexistent
    FileUtils.rmdir Gem.fetch_cache_dir

    refute @fetcher.update_cache?
  end

end
