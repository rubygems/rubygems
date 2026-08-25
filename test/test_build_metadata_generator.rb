# frozen_string_literal: true

require "tmpdir"
require "bundler"
require_relative "../bundler/spec/support/build_metadata"
require_relative "rubygems/helper"

class BuildMetadataGeneratorTest < Test::Unit::TestCase
  def test_release_date_for_extracts_the_date_from_the_current_changelog_header_format
    Dir.mktmpdir do |dir|
      write_changelog(dir, "## 9.9.9 / 2026-08-05")

      assert_equal "2026-08-05", Spec::BuildMetadata.send(:release_date_for, "9.9.9", dir: dir)
    end
  end

  def test_release_date_for_returns_nil_when_the_changelog_has_no_entry_for_the_version
    Dir.mktmpdir do |dir|
      write_changelog(dir, "## 1.0.0 / 2026-01-01")

      assert_nil Spec::BuildMetadata.send(:release_date_for, "9.9.9", dir: dir)
    end
  end

  private

  def write_changelog(dir, header)
    File.write(File.join(dir, "CHANGELOG.md"), <<~CHANGELOG)
      # Changelog

      #{header}

      ### Enhancements:
    CHANGELOG
  end
end
