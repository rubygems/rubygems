# frozen_string_literal: true

require_relative "helper"
require "rubygems/platform/manylinux"

class TestGemPlatformManylinux < Gem::TestCase
  def test_parse_glibc_version
    # Test glibc version parsing
    assert_equal [2, 17], Gem::Platform::Manylinux.parse_glibc_version("2.17")
    assert_equal [2, 31], Gem::Platform::Manylinux.parse_glibc_version("2.31-ubuntu1")
    assert_nil Gem::Platform::Manylinux.parse_glibc_version("invalid")
    assert_nil Gem::Platform::Manylinux.parse_glibc_version("")
  end

  def test_platform_tags
    glibc_version = [2, 17]

    expected_tags = [
      "manylinux_2_17_x86_64", "manylinux_2_16_x86_64", "manylinux_2_15_x86_64",
      "manylinux_2_14_x86_64", "manylinux_2_13_x86_64", "manylinux_2_12_x86_64",
      "manylinux_2_11_x86_64", "manylinux_2_10_x86_64", "manylinux_2_9_x86_64",
      "manylinux_2_8_x86_64", "manylinux_2_7_x86_64", "manylinux_2_6_x86_64",
      "manylinux_2_5_x86_64"
    ]

    actual_tags = Gem::Platform::Manylinux.platform_tags(["x86_64"], glibc_version).to_a
    assert_equal expected_tags, actual_tags
  end

  def test_architecture_support
    glibc_version = [2, 17]

    # Test x86_64 architecture (supports back to glibc 2.5)
    x86_64_tags = Gem::Platform::Manylinux.platform_tags(["x86_64"], glibc_version).to_a
    assert x86_64_tags.include?("manylinux_2_5_x86_64")
    assert x86_64_tags.include?("manylinux_2_12_x86_64")
    assert x86_64_tags.include?("manylinux_2_17_x86_64")

    # Test aarch64 architecture (supports back to glibc 2.17 only)
    aarch64_tags = Gem::Platform::Manylinux.platform_tags(["aarch64"], glibc_version).to_a
    refute aarch64_tags.include?("manylinux_2_5_aarch64")
    refute aarch64_tags.include?("manylinux_2_12_aarch64")
    assert aarch64_tags.include?("manylinux_2_17_aarch64")
  end

  def test_no_glibc_returns_empty
    # Mock glibc version detection to return nil (no glibc)
    Gem::Platform::Manylinux.instance_variable_set(:@glibc_version, nil)

    glibc_ver = Gem::Platform::Manylinux.glibc_version
    tags = []
    Gem::Platform::Manylinux.platform_tags(["x86_64"], glibc_ver) {|tag| tags << tag } if glibc_ver
    assert_empty tags
  ensure
    Gem::Platform::Manylinux.remove_instance_variable(:@glibc_version)
  end

  def test_standard_tag_format
    glibc_version = [2, 17]

    tags = Gem::Platform::Manylinux.platform_tags(["x86_64"], glibc_version).to_a

    # Check that only standard manylinux_maj_min_arch format is used
    assert_includes tags, "manylinux_2_5_x86_64"
    assert_includes tags, "manylinux_2_12_x86_64"
    assert_includes tags, "manylinux_2_17_x86_64"

    # Verify no legacy tags are present
    refute tags.any? {|tag| tag.match?(/^manylinux[0-9]+_/) }
    refute tags.any? {|tag| tag.match?(/^manylinux[0-9]{4}_/) }
  end

  def test_version_compatibility_ordering
    glibc_version = [2, 17]

    tags = Gem::Platform::Manylinux.platform_tags(["x86_64"], glibc_version).to_a

    # Verify that newer versions come first (more specific)
    manylinux_2_17_index = tags.index("manylinux_2_17_x86_64")
    manylinux_2_16_index = tags.index("manylinux_2_16_x86_64")
    manylinux_2_5_index = tags.index("manylinux_2_5_x86_64")

    assert manylinux_2_17_index < manylinux_2_16_index
    assert manylinux_2_16_index < manylinux_2_5_index
  end
end
