require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/indexer'
require 'rubygems/commands/generate_index_command'

class TestGemCommandsGenerateIndexCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::GenerateIndexCommand.new
    @cmd.options[:directory] = @gemhome
  end

  def test_execute
    use_ui @ui do
      @cmd.execute
    end

    yaml = File.join @gemhome, 'yaml'
    yaml_z = File.join @gemhome, 'yaml.Z'
    quick_index = File.join @gemhome, 'quick', 'index'
    quick_index_rz = File.join @gemhome, 'quick', 'index.rz'

    assert File.exist?(yaml), yaml
    assert File.exist?(yaml_z), yaml_z
    assert File.exist?(quick_index), quick_index
    assert File.exist?(quick_index_rz), quick_index_rz
  end

  def test_handle_options_directory
    refute_equal '/nonexistent', @cmd.options[:directory]

    @cmd.handle_options %w[--directory /nonexistent]

    assert_equal '/nonexistent', @cmd.options[:directory]
  end

  def test_handle_options_invalid
    e = assert_raises OptionParser::InvalidOption do
      @cmd.handle_options %w[--no-modern --no-legacy]
    end

    assert_equal 'invalid option: --no-legacy no indicies will be built',
                 e.message

    @cmd = Gem::Commands::GenerateIndexCommand.new
    e = assert_raises OptionParser::InvalidOption do
      @cmd.handle_options %w[--no-legacy --no-modern]
    end

    assert_equal 'invalid option: --no-modern no indicies will be built',
                 e.message
  end

  def test_handle_options_legacy
    @cmd.handle_options %w[--legacy]

    assert @cmd.options[:build_legacy]
    assert @cmd.options[:build_modern], ':build_modern not set'
  end

  def test_handle_options_modern
    @cmd.handle_options %w[--modern]

    assert @cmd.options[:build_legacy]
    assert @cmd.options[:build_modern], ':build_modern not set'
  end

  def test_handle_options_no_legacy
    @cmd.handle_options %w[--no-legacy]

    refute @cmd.options[:build_legacy]
    assert @cmd.options[:build_modern]
  end

  def test_handle_options_no_modern
    @cmd.handle_options %w[--no-modern]

    assert @cmd.options[:build_legacy]
    refute @cmd.options[:build_modern]
  end

  def test_handle_options_update
    @cmd.handle_options %w[--update]

    assert @cmd.options[:update]
  end

end if ''.respond_to? :to_xs

