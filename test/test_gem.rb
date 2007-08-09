require 'test/unit'
require 'test/gemutilities'
require 'rubygems'

class TestGem < RubyGemTestCase

  def test_self_clear_paths
    Gem.dir
    Gem.path
    searcher = Gem.searcher
    source_index = Gem.source_index

    Gem.clear_paths

    assert_equal nil, Gem.instance_variable_get(:@gem_home)
    assert_equal nil, Gem.instance_variable_get(:@gem_path)
    assert_not_equal searcher, Gem.searcher
    assert_not_equal source_index, Gem.source_index
  end

  def test_self_configuration
    expected = {}
    Gem.send :instance_variable_set, :@configuration, nil

    assert_equal expected, Gem.configuration

    Gem.configuration[:verbose] = true
    expected[:verbose] = true

    assert_equal expected, Gem.configuration
    assert_equal true, Gem.configuration.verbose, 'method_missing on Hash'
  end

  def test_self_dir
    assert_equal @gemhome, Gem.dir
  end

  def test_self_loaded_specs
    foo = quick_gem 'foo'
    use_ui @ui do
      Dir.chdir @tempdir do
        Gem::Builder.new(foo).build
      end
    end

    Gem::Installer.new(File.join(@tempdir, "#{foo.full_name}.gem")).install

    Gem.activate 'foo', false

    assert_equal true, Gem.loaded_specs.keys.include?('foo')
  end

  def test_self_path
    assert_equal [Gem.dir], Gem.path
  end

  def test_self_searcher
    assert_kind_of Gem::GemPathSearcher, Gem.searcher
  end

  def test_self_source_index
    assert_kind_of Gem::SourceIndex, Gem.source_index
  end

end

