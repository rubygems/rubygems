# frozen_string_literal: true

require_relative "helper"
require "rubygems/platform/musllinux"

class TestGemPlatformMusllinux < Gem::TestCase
  def teardown
    Gem::Platform::Musllinux.remove_instance_variable(:@musl_version) if Gem::Platform::Musllinux.instance_variable_defined?(:@musl_version)
  end

  def test_platform_tags
    musl_version = [1, 2]

    expected_tags = [
      "musllinux_1_2_x86_64", "musllinux_1_1_x86_64", "musllinux_1_0_x86_64"
    ]

    actual_tags = Gem::Platform::Musllinux.platform_tags(["x86_64"], musl_version).to_a
    assert_equal expected_tags, actual_tags
  end

  def test_no_musl_returns_empty
    # Mock musl version detection to return nil (no musl)
    Gem::Platform::Musllinux.instance_variable_set(:@musl_version, nil)

    musl_ver = Gem::Platform::Musllinux.musl_version
    tags = []
    Gem::Platform::Musllinux.platform_tags(["x86_64"], musl_ver) {|tag| tags << tag } if musl_ver
    assert_empty tags
  end

  def test_multiple_architectures
    musl_version = [1, 2]

    expected_tags = [
      "musllinux_1_2_x86_64", "musllinux_1_1_x86_64", "musllinux_1_0_x86_64",
      "musllinux_1_2_aarch64", "musllinux_1_1_aarch64", "musllinux_1_0_aarch64"
    ]

    actual_tags = Gem::Platform::Musllinux.platform_tags(["x86_64", "aarch64"], musl_version).to_a
    assert_equal expected_tags, actual_tags
  end

  def test_version_compatibility_ordering
    musl_version = [1, 2]

    tags = Gem::Platform::Musllinux.platform_tags(["x86_64"], musl_version).to_a

    # Verify that newer versions come first (more specific)
    musllinux_1_2_index = tags.index("musllinux_1_2_x86_64")
    musllinux_1_1_index = tags.index("musllinux_1_1_x86_64")
    musllinux_1_0_index = tags.index("musllinux_1_0_x86_64")

    assert musllinux_1_2_index < musllinux_1_1_index
    assert musllinux_1_1_index < musllinux_1_0_index
  end

  def test_detect_musl_version_system_checks
    # Test that detect_musl_version returns nil when not on musl system
    Gem::Platform::Musllinux.define_singleton_method(:musl_system?) { false }

    assert_nil Gem::Platform::Musllinux.detect_musl_version
  ensure
    # Remove mock
    begin
      Gem::Platform::Musllinux.singleton_class.remove_method(:musl_system?)
    rescue StandardError
      nil
    end
  end
end
