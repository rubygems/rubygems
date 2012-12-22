require 'rubygems/test_case'
require 'rubygems/commands/check_command'

class TestGemCommandsCheckCommand < Gem::TestCase

  def setup
    super

    @cmd = Gem::Commands::CheckCommand.new
  end

  def gem name
    spec = quick_gem name do |gem|
      gem.files = %W[lib/#{name}.rb Rakefile]
    end

    write_file File.join(*%W[gems #{spec.full_name} lib #{name}.rb])
    write_file File.join(*%W[gems #{spec.full_name} Rakefile])

    spec
  end

  def test_initialize
    assert_equal "check", @cmd.command
    assert_equal "gem check", @cmd.program_name
    assert_match(/Check/, @cmd.summary)
  end

  def test_handle_options
    @cmd.handle_options %w[--no-alien --no-gems --doctor]

    refute @cmd.options[:alien]
    refute @cmd.options[:gems]
    assert @cmd.options[:doctor]
  end

  def test_handle_options_defaults
    @cmd.handle_options []

    assert @cmd.options[:alien]
    assert @cmd.options[:gems]
    refute @cmd.options[:doctor]
  end

  def test_doctor
    a = gem 'a'
    b = gem 'b'
    c = gem 'c'

    FileUtils.rm b.spec_file

    open c.spec_file, 'w' do |io|
      io.write 'this will raise an exception when evaluated.'
    end

    assert_path_exists File.join(a.gem_dir, 'Rakefile')
    assert_path_exists File.join(a.gem_dir, 'lib', 'a.rb')

    assert_path_exists b.gem_dir
    refute_path_exists b.spec_file

    assert_path_exists c.gem_dir
    assert_path_exists c.spec_file

    Gem.use_paths @gemhome

    capture_io do
      use_ui @ui do
        @cmd.doctor
      end
    end

    assert_path_exists File.join(a.gem_dir, 'Rakefile')
    assert_path_exists File.join(a.gem_dir, 'lib', 'a.rb')

    refute_path_exists b.gem_dir
    refute_path_exists b.spec_file

    refute_path_exists c.gem_dir
    refute_path_exists c.spec_file

    expected = <<-OUTPUT
Checking for files from uninstalled gems...

Checking #{@gemhome}
Removed directory gems/b-2
Removed directory gems/c-2
Removed file specifications/c-2.gemspec
    OUTPUT

    assert_equal expected, @ui.output
  end

  def test_doctor_non_gem_home
    other_dir = File.join @tempdir, 'other', 'dir'

    FileUtils.mkdir_p other_dir

    Gem.use_paths @tempdir

    capture_io do
      use_ui @ui do
        @cmd.doctor
      end
    end

    assert_path_exists other_dir

    expected = <<-OUTPUT
Checking for files from uninstalled gems...

Checking #{@tempdir}
This directory does not appear to be a RubyGems repository, skipping
    OUTPUT

    assert_equal expected, @ui.output
  end

end
