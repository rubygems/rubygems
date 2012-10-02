require "rubygems/test_case"
require "rubygems/commands/patch_command"

class TestGemCommandsPatchCommand < Gem::TestCase
  def setup
    super

    @command = Gem::Commands::PatchCommand.new
  end

  def test_execute_no_gemfile
    @command.options[:args] = []

    e = assert_raises Gem::CommandLineError do
      use_ui @ui do
        @command.execute
      end
    end

    assert_match 'Please specify a gem file on the command line (e.g. gem patch foo-0.1.0.gem PATCH [PATCH ...])', e.message
  end

  def test_execute_no_patch
    @command.options[:args] = ['Gemfile.gem']

    e = assert_raises Gem::CommandLineError do
      use_ui @ui do
        @command.execute
      end
    end

    assert_match 'Please specify patches to apply (e.g. gem patch foo-0.1.0.gem foo.patch bar.patch ...)', e.message
  end
end