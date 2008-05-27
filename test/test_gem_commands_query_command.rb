require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')
require 'rubygems/commands/query_command'

class TestGemCommandsQueryCommand < RubyGemTestCase

  def setup
    super

    @cmd = Gem::Commands::QueryCommand.new

    util_setup_fake_fetcher
    @a2.summary = 'This is a lot of text. ' * 4

    @si = util_setup_spec_fetcher @a1, @a2, @pl1

    @fetcher.data["#{@gem_repo}/Marshal.#{Gem.marshal_version}"] = proc do
      raise Gem::RemoteFetcher::FetchError
    end
  end

  def test_execute
    @cmd.handle_options %w[-r]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a (2)
pl (1)
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_all
    a1_name = @a1.full_name
    a2_name = @a2.full_name

    @cmd.handle_options %w[-r --all]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a (2, 1)
pl (1)
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_details
    @cmd.handle_options %w[-r -d]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a (2)
    This is a lot of text. This is a lot of text. This is a lot of text.
    This is a lot of text.

pl (1)
    this is a summary
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_installed
    @cmd.handle_options %w[-n c --installed]

    e = assert_raise Gem::SystemExitException do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_equal 0, e.exit_code

    assert_equal "true\n", @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_installed_no_name
    @cmd.handle_options %w[--installed]

    e = assert_raise Gem::SystemExitException do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_equal '', @ui.output
    assert_equal "ERROR:  You must specify a gem name\n", @ui.error

    assert_equal 4, e.exit_code
  end

  def test_execute_installed_not_installed
    @cmd.handle_options %w[-n not_installed --installed]

    e = assert_raise Gem::SystemExitException do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_equal "false\n", @ui.output
    assert_equal '', @ui.error

    assert_equal 1, e.exit_code
  end

  def test_execute_installed_version
    @cmd.handle_options %w[-n c --installed --version 1.2]

    e = assert_raise Gem::SystemExitException do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_equal "true\n", @ui.output
    assert_equal '', @ui.error

    assert_equal 0, e.exit_code
  end

  def test_execute_installed_version_not_installed
    @cmd.handle_options %w[-n c --installed --version 2]

    e = assert_raise Gem::SystemExitException do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_equal "false\n", @ui.output
    assert_equal '', @ui.error

    assert_equal 1, e.exit_code
  end

  def test_execute_no_versions
    @cmd.handle_options %w[-r --no-versions]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF

*** REMOTE GEMS ***

a
pl
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

end

