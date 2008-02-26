require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/commands/update_command'

class TestGemCommandsUpdateCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::UpdateCommand.new

    util_setup_fake_fetcher

    @gem1_3 = quick_gem 'gem_one', '3' do |gem|
      gem.files = %w[Rakefile lib/gem_one.rb]
    end

    util_build_gem @gem1
    util_build_gem @gem1_3

    @source_index.add_spec @gem1_3

    @gem1_path = File.join @gemhome, 'cache', "#{@gem1.full_name}.gem"
    @gem1_3_path = File.join @gemhome, 'cache', "#{@gem1_3.full_name}.gem"

    @fetcher.data["#{@gem_repo}/Marshal.#{@marshal_version}"] =
      @source_index.dump
    @fetcher.data["#{@gem_repo}/gems/#{@gem1.full_name}.gem"] =
      File.read(@gem1_path)
    @fetcher.data["#{@gem_repo}/gems/#{@gem1_3.full_name}.gem"] =
      File.read(@gem1_3_path)

    FileUtils.rm_r File.join(@gemhome, 'gems')
    FileUtils.rm_r File.join(@gemhome, 'specifications')
  end

  def test_execute
    Gem::Installer.new(@gem1_path).install

    @cmd.options[:args] = []

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_equal "Updating installed gems", out.shift
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Attempting remote update of gem_one", out.shift
    assert_equal "Successfully installed #{@gem1_3.full_name}", out.shift
    assert_equal "1 gem installed", out.shift
    assert_equal "Installing ri documentation for #{@gem1_3.full_name}...",
                 out.shift
    assert_equal "Installing RDoc documentation for #{@gem1_3.full_name}...",
                 out.shift
    assert_equal "Gems updated: gem_one", out.shift

    assert out.empty?, out.inspect
  end

  def test_execute_up_to_date
    Gem::Installer.new(@gem1_3_path).install

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
    Gem::Installer.new(@gem1_path).install

    @cmd.options[:args] = [@gem1.name]

    use_ui @ui do
      @cmd.execute
    end

    out = @ui.output.split "\n"
    assert_equal "Updating installed gems", out.shift
    assert_match %r|Bulk updating|, out.shift
    assert_equal "Attempting remote update of gem_one", out.shift
    assert_equal "Successfully installed #{@gem1_3.full_name}", out.shift
    assert_equal "1 gem installed", out.shift
    assert_equal "Installing ri documentation for #{@gem1_3.full_name}...",
                 out.shift
    assert_equal "Installing RDoc documentation for #{@gem1_3.full_name}...",
                 out.shift
    assert_equal "Gems updated: gem_one", out.shift

    assert out.empty?, out.inspect
  end

  def test_execute_named_up_to_date
    Gem::Installer.new(@gem1_3_path).install

    @cmd.options[:args] = [@gem1.name]

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

