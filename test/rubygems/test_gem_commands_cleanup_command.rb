require 'rubygems/test_case'
require 'rubygems/commands/cleanup_command'

class TestGemCommandsCleanupCommand < Gem::TestCase

  def setup
    super

    @cmd = Gem::Commands::CleanupCommand.new

    @a_1 = quick_spec 'a', 1
    @a_2 = quick_spec 'a', 2

    install_gem @a_1
    install_gem @a_2
  end

  def test_execute
    @cmd.options[:args] = %w[a]

    @cmd.execute

    refute_path_exists @a_1.gem_dir
  end

  def test_execute_all
    gemhome2 = File.join @tempdir, 'gemhome2'

    Gem.ensure_gem_subdirectories gemhome2

    Gem.use_paths @gemhome, gemhome2

    @b_1 = quick_spec 'b', 1
    @b_2 = quick_spec 'b', 2

    install_gem @b_1
    install_gem @b_2

    @cmd.options[:args] = []

    @cmd.execute

    assert_equal @gemhome, Gem.dir, 'GEM_HOME'
    assert_equal [@gemhome, gemhome2], Gem.path.sort, 'GEM_PATH'

    refute_path_exists @a_1.gem_dir
    refute_path_exists @b_1.gem_dir
  end

  def test_execute_all_user
    @a_1_1 = quick_spec 'a', '1.1'
    @a_1_1 = install_gem_user @a_1_1 # pick up user install path

    Gem::Specification.dirs = [Gem.dir, Gem.user_dir]

    assert_path_exists @a_1.gem_dir
    assert_path_exists @a_1_1.gem_dir

    @cmd.options[:args] = %w[a]

    @cmd.execute

    refute_path_exists @a_1.gem_dir
    refute_path_exists @a_1_1.gem_dir
  end

  def test_execute_all_user_no_sudo
    FileUtils.chmod 0555, @gemhome

    @a_1_1 = quick_spec 'a', '1.1'
    @a_1_1 = install_gem_user @a_1_1 # pick up user install path

    Gem::Specification.dirs = [Gem.dir, Gem.user_dir]

    assert_path_exists @a_1.gem_dir
    assert_path_exists @a_1_1.gem_dir

    @cmd.options[:args] = %w[a]

    @cmd.execute

    assert_path_exists @a_1.gem_dir
    refute_path_exists @a_1_1.gem_dir
  ensure
    FileUtils.chmod 0755, @gemhome
  end unless win_platform?

  def test_execute_dry_run
    @cmd.options[:args] = %w[a]
    @cmd.options[:dryrun] = true

    @cmd.execute

    assert_path_exists @a_1.gem_dir
  end

  def test_execute_keeps_older_versions_with_deps
    @b_1 = quick_spec 'b', 1
    @b_2 = quick_spec 'b', 2

    @c = quick_spec 'c', 1 do |s|
      s.add_dependency 'b', '1'
    end

    install_gem @c
    install_gem @b_1
    install_gem @b_2

    @cmd.options[:args] = []

    @cmd.execute

    assert_path_exists @b_1.gem_dir
  end

  def test_execute_ignore_default_gem
    @b_1 = quick_spec 'b', 1
    @b_default = new_default_spec "b", "2"
    @b_2 = quick_spec 'b', 3

    install_gem @b_1
    install_default_specs @b_default
    install_gem @b_2

    ui = Gem::MockGemUi.new

    @cmd.options[:args] = []

    use_ui ui do
      @cmd.execute
    end

    expected = [
     "Cleaning up installed gems...",
     "Attempting to uninstall b-1",
     "Successfully uninstalled b-1",
     "Attempting to uninstall a-1",
     "Successfully uninstalled a-1",
     "Clean Up Complete",
    ].join "\n"
    assert_equal expected, ui.output.chomp
    assert_equal "", ui.error
  end
end

