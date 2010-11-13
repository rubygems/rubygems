require File.expand_path('../gemutilities', __FILE__)
require 'rubygems/commands/which_command'

class TestGemCommandsWhichCommand < RubyGemTestCase

  def setup
    super
    @cmd = Gem::Commands::WhichCommand.new
    @foo_bar, @foo_bar2 = nil
  end

  def test_execute
    util_foo_bar

    @cmd.handle_options %w[foo_bar]

    use_ui @ui do
      @cmd.execute
    end

    assert_equal "#{@foo_bar.full_gem_path}/lib/foo_bar.rb\n", @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_one_missing
    util_foo_bar

    @cmd.handle_options %w[foo_bar missing]

    use_ui @ui do
      @cmd.execute rescue nil
    end

    assert_equal "#{@foo_bar.full_gem_path}/lib/foo_bar.rb\n", @ui.output
    assert_match %r%Can't find ruby library file or shared library missing\n%,
    @ui.error
  end

  def test_execute_missing
    @cmd.handle_options %w[missing]

    use_ui @ui do
      assert_raises MockGemUi::TermError do
        @cmd.execute
      end
    end

    assert_equal '', @ui.output
    assert_match %r%Can't find ruby library file or shared library missing\n%,
    @ui.error
  end

  def test_execute_find_all
    util_foo_bar

    @cmd.handle_options %w[-a foo_bar]

    use_ui @ui do
      @cmd.execute
    end

    expected = [
      "#{@foo_bar.full_gem_path}/lib/foo_bar.rb\n",
      "#{@foo_bar2.full_gem_path}/lib/foo_bar.rb\n"
    ]

    assert_equal '', @ui.error
    assert_equal expected.join, @ui.output
  end

  def test_order_load_path_then_gems
    util_foo_bar

    $LOAD_PATH << @foo_bar.full_gem_path
    $LOAD_PATH << @foo_bar2.full_gem_path

    @cmd.handle_options %w[-a foo_bar]

    use_ui @ui do
      @cmd.execute
    end

    expected = [
      "#{@foo_bar.full_gem_path}/lib/foo_bar.rb\n",
      "#{@foo_bar2.full_gem_path}/lib/foo_bar.rb\n"
    ]

    assert_equal '', @ui.error
    assert_equal expected.join, @ui.output
  ensure
    $LOAD_PATH.delete(@foo_bar.full_gem_path)
    $LOAD_PATH.delete(@foo_bar2.full_gem_path)
  end

  def util_foo_bar
    files = %w[lib/foo_bar.rb Rakefile]
    @foo_bar = quick_gem 'foo_bar' do |gem|
      gem.files = files
    end
    make_files(files, @foo_bar)

    @foo_bar2 = quick_gem 'foo_bar2' do |gem|
      gem.files = files
    end
    make_files(files, @foo_bar2)
  end

  def make_files(files, g)
    files.each do |file|
      filename = g.full_gem_path + "/#{file}"
      FileUtils.mkdir_p File.dirname(filename)
      FileUtils.touch filename
    end
  end

end

