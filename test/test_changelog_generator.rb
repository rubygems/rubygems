# frozen_string_literal: true

require_relative "../tool/changelog"
require_relative "rubygems/helper"

class ChangelogTest < Test::Unit::TestCase
  def setup
    @changelog = Changelog.for_rubygems(Gem::VERSION)
  end

  def test_format_header
    Time.stub :now, Time.new(2020, 1, 1) do
      assert_match %r{^##\s*[\d.a-zA-Z]+\s*/\s*\d{4}-\d{2}-\d{2}\s*$}, @changelog.send(:format_header)
    end
  end
end
