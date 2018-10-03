# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/commands/version_command'

class TestGemCommandsVersionCommand < Gem::TestCase

  def setup
    super

    @cmd = Gem::Commands::VersionCommand.new
  end

  def test_execute
    use_ui @ui do
      @cmd.execute
    end

    assert_match "#{Gem::VERSION}", @ui.output
  end
end

