require 'test/unit'
require 'test/gemutilities'
require 'rubygems/commands/pristine_command'

class TestGemCommandsPristineCommand < RubyGemTestCase

  def setup
    super
    @cmd = Gem::Commands::PristineCommand.new
  end

  def test_execute
    a = quick_gem 'a' do |s| s.executables = %w[foo] end
    FileUtils.mkdir_p File.join(@tempdir, 'bin')
    File.open File.join(@tempdir, 'bin', 'foo'), 'w' do |fp|
      fp.puts "#!/usr/bin/ruby"
    end

    install_gem a

    @cmd.options[:args] = %w[a]

    use_ui @ui do
      @cmd.execute
    end

    assert_match %r|Restoring gem\(s\) to pristine condition...|, @ui.output
    assert_match %r|Rebuilt all bin stubs|, @ui.output
    assert_match %r|#{a.full_name} is already in pristine condition|, @ui.output
  end

  def test_execute_no_gem
    @cmd.options[:args] = %w[]

    e = assert_raise Gem::CommandLineError do
      use_ui @ui do
        @cmd.execute
      end
    end

    assert_match %r|specify a gem name|, e.message
  end

end

