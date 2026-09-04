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

class ChangelogHeaderTest < Test::Unit::TestCase
  def setup
    @header = ChangelogHeader.for("bundler")
  end

  def test_release_date
    Time.stub :now, Time.new(2020, 1, 1) do
      assert_equal "2020-01-01", @header.release_date
    end
  end

  def test_format_stamps_the_header_with_the_release_date
    Time.stub :now, Time.new(2020, 1, 1) do
      assert_equal "## 9.9.9 / #{@header.release_date}", @header.format("9.9.9")
    end
  end
end
