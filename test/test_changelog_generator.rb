# frozen_string_literal: true

require "minitest/autorun"
require_relative "../util/changelog"
require "rubygems/commands/setup_command"

class ChangelogTest < Minitest::Test
  def setup
    @changelog = Changelog.for_rubygems(Gem::VERSION)
  end

  def test_format_header
    Time.stub :now, Time.new(2020, 1, 1) do
      assert_match Gem::Commands::SetupCommand::HISTORY_HEADER, @changelog.send(:format_header)
    end
  end
end
