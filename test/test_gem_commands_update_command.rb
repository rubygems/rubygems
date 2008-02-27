require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/commands/update_command'

class TestGemCommandsUpdateCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::UpdateCommand.new

    util_setup_fake_fetcher

    @a1_path = File.join @gemhome, 'cache', "#{@a1.full_name}.gem"
    @a2_path = File.join @gemhome, 'cache', "#{@a2.full_name}.gem"

    @fetcher.data["#{@gem_repo}/Marshal.#{@marshal_version}"] =
      @source_index.dump
    @fetcher.data["#{@gem_repo}/gems/#{@a1.full_name}.gem"] = File.read @a1_path
    @fetcher.data["#{@gem_repo}/gems/#{@a2.full_name}.gem"] = File.read @a2_path

    FileUtils.rm_r File.join(@gemhome, 'gems')
    FileUtils.rm_r File.join(@gemhome, 'specifications')
  end

  def test_execute
    Gem::Installer.new(@a1_path).install

    @cmd.options[:args] = []

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_equal "Updating installed gems", out.shift
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Attempting remote update of #{@a2.name}", out.shift
    assert_equal "Successfully installed #{@a2.full_name}", out.shift
    assert_equal "1 gem installed", out.shift
    assert_equal "Installing ri documentation for #{@a2.full_name}...",
                 out.shift
    assert_equal "Installing RDoc documentation for #{@a2.full_name}...",
                 out.shift
    assert_equal "Gems updated: #{@a2.name}", out.shift

    assert out.empty?, out.inspect
  end

  def test_execute_up_to_date
    Gem::Installer.new(@a2_path).install

    @cmd.options[:args] = []

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_equal "Updating installed gems", out.shift
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Nothing to update", out.shift

    assert out.empty?, out.inspect
  end

  def test_execute_named
    Gem::Installer.new(@a1_path).install

    @cmd.options[:args] = [@a1.name]

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_equal "Updating installed gems", out.shift
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Attempting remote update of #{@a2.name}", out.shift
    assert_equal "Successfully installed #{@a2.full_name}", out.shift
    assert_equal "1 gem installed", out.shift
    assert_equal "Installing ri documentation for #{@a2.full_name}...",
                 out.shift
    assert_equal "Installing RDoc documentation for #{@a2.full_name}...",
                 out.shift
    assert_equal "Gems updated: #{@a2.name}", out.shift

    assert out.empty?, out.inspect
  end

  def test_execute_named_up_to_date
    Gem::Installer.new(@a2_path).install

    @cmd.options[:args] = [@a2.name]

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_equal "Updating installed gems", out.shift
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Nothing to update", out.shift

    assert out.empty?, out.inspect
  end

end

