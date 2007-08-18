require 'test/unit'
require 'test/gemutilities'
require 'rubygems/commands/install_command'

class TestGemCommandsInstallCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::InstallCommand.new
    @cmd.options[:generate_rdoc] = false
    @cmd.options[:generate_ri] = false
  end

  def test_execute_local
    util_setup_fake_fetcher
    @cmd.options[:domain] = :local

    gem1 = quick_gem 'gem_one'
    util_build_gem gem1
    FileUtils.mv File.join(@gemhome, 'cache', "#{@gem1.full_name}.gem"),
                 File.join(@tempdir)

    @cmd.options[:args] = [gem1.name]

    use_ui @ui do
      orig_dir = Dir.pwd
      begin
        Dir.chdir @tempdir
        @cmd.execute
      ensure
        Dir.chdir orig_dir
      end
    end

    out = @ui.output.split "\n"
    assert_equal "Successfully installed #{@gem1.full_name}", out.shift
    assert out.empty?, out.inspect
  end

  def test_execute_local_missing
    util_setup_fake_fetcher
    @cmd.options[:domain] = :local

    @cmd.options[:args] = %w[gem_one]

    assert_raise MockGemUi::TermError do
      use_ui @ui do
        @cmd.execute
      end
    end

    err = @ui.error.split "\n"
    assert_equal "ERROR:  Local gem file not found: gem_one*.gem", err.shift
    assert_equal "ERROR:  Could not install a local or remote copy of the gem: gem_one",
                 err.shift
    assert err.empty?, err.inspect
  end

  def test_execute_no_gem
    @cmd.options[:args] = %w[]

    assert_raise Gem::CommandLineError do
      @cmd.execute
    end
  end

  def test_execute_nonexistent
    util_setup_fake_fetcher
    @fetcher.data['http://gems.example.com/yaml'] = @source_index.to_yaml

    @cmd.options[:args] = %w[nonexistent]

    e = assert_raise Gem::GemNotFoundException do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_equal 'Could not find nonexistent (>= 0) in any repository',
                 e.message
  end

  def test_execute_remote
    @cmd.options[:generate_rdoc] = true
    @cmd.options[:generate_ri] = true
    util_setup_fake_fetcher

    util_build_gem @gem1
    @fetcher.data['http://gems.example.com/yaml'] = @source_index.to_yaml
    @fetcher.data['http://gems.example.com/gems/gem_one-0.0.2.gem'] =
      File.read(File.join(@gemhome, 'cache', "#{@gem1.full_name}.gem"))

    @cmd.options[:args] = [@gem1.name]

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Successfully installed #{@gem1.full_name}", out.shift
    assert_equal "Installing ri documentation for #{@gem1.full_name}...",
                 out.shift
    assert_equal "Installing RDoc documentation for #{@gem1.full_name}...",
                 out.shift
    assert out.empty?, out.inspect
  end

end

