require 'test/unit'
require 'rubygems'
require 'sources'

class TestGem < Test::Unit::TestCase

  def test_self_clear_paths
    Gem.dir
    Gem.path
    Gem.searcher
    Gem.source_index

    Gem.clear_paths

    assert_equal nil, Gem.instance_variable_get(:@gem_home)
    assert_equal nil, Gem.instance_variable_get(:@gem_path)
    assert_equal nil, Gem.instance_variable_get(:@searcher)
    assert_equal nil, Gem.class_eval('@@source_index')
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
    assert_equal File.join(Config::CONFIG['libdir'], 'ruby', 'gems',
                           Config::CONFIG['ruby_version']),
                 Gem.dir
  end

  def test_self_loaded_specs
    assert_equal true, Gem.loaded_specs.keys.include?('sources')
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

