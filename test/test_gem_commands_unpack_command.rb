require 'test/unit'
require 'test/gemutilities'
require 'rubygems/commands/unpack_command'

class TestGemCommandsUnpackCommand < RubyGemTestCase

  def setup
    super

    @ui = MockGemUi.new
    @cmd = Gem::Commands::UnpackCommand.new
  end

  def test_execute
    gem = File.join 'test', 'data', 'a-0.0.1.gem'
    cache_gem = File.join @gemhome, 'cache', 'a-0.0.1.gem'
    FileUtils.cp gem, cache_gem
    installer = Gem::Installer.new cache_gem
    installer.install

    @cmd.options[:args] = %w[a]

    use_ui @ui do
      Dir.chdir @tempdir do
        @cmd.execute
      end
    end

    assert File.exist?(File.join(@tempdir, 'a-0.0.1'))
  end

  def test_execute_exact_match
    foo_spec = quick_gem 'foo'
    foo_bar_spec = quick_gem 'foo_bar'

    use_ui @ui do
      Dir.chdir @tempdir do
        Gem::Builder.new(foo_spec).build
        Gem::Builder.new(foo_bar_spec).build
      end
    end

    foo_path = File.join(@tempdir, "#{foo_spec.full_name}.gem")
    foo_bar_path = File.join(@tempdir, "#{foo_bar_spec.full_name}.gem")
    Gem::Installer.new(foo_path).install
    Gem::Installer.new(foo_bar_path).install

    @cmd.options[:args] = %w[foo]

    use_ui @ui do
      Dir.chdir @tempdir do
        @cmd.execute
      end
    end

    assert File.exist?(File.join(@tempdir, foo_spec.full_name))
  end

end

