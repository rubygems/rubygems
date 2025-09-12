# frozen_string_literal: true

require_relative "helper"
require "rubygems/platform"

class TestGemPlatformWheel < Gem::TestCase
  def test_initialize_valid_wheel_string
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-musllinux_1_2_x86_64")
    assert_equal "rb3_cr33", wheel.ruby_abi_tag
    assert_equal "musllinux_1_2_x86_64", wheel.platform_tags
  end

  def test_initialize_invalid_wheel_string_wrong_prefix
    assert_raise(ArgumentError) do
      Gem::Platform::Wheel.new("invalid-rb3_cr33-musllinux_1_2_x86_64")
    end
  end

  def test_initialize_invalid_wheel_string_missing_parts
    assert_raise(ArgumentError) do
      Gem::Platform::Wheel.new("whl-rb3_cr33")
    end
  end

  def test_initialize_invalid_wheel_string_too_many_parts
    # The split with limit 3 means extra hyphens become part of platform_tags
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-linux-extra-part")
    assert_equal "rb3_cr33", wheel.ruby_abi_tag
    assert_equal "linux_extra_part", wheel.platform_tags
  end

  def test_to_s
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-musllinux_1_2_x86_64")
    assert_equal "whl-rb3_cr33-musllinux_1_2_x86_64", wheel.to_s
  end

  def test_to_a
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-musllinux_1_2_x86_64")
    assert_equal ["whl", "rb3_cr33", "musllinux_1_2_x86_64"], wheel.to_a
  end

  def test_expand_single_tags
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-linux_x86_64")
    expected = [["rb3_cr33", "linux_x86_64"]]
    assert_equal expected, wheel.expand
  end

  def test_expand_multiple_ruby_abi_tags
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33.rb3_cr34-linux_x86_64")
    expected = [
      ["rb3_cr33", "linux_x86_64"],
      ["rb3_cr34", "linux_x86_64"],
    ]
    assert_equal expected, wheel.expand
  end

  def test_expand_multiple_platform_tags
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-linux_x86_64.linux_aarch64")
    expected = [
      ["rb3_cr33", "linux_aarch64"],
      ["rb3_cr33", "linux_x86_64"],
    ]
    assert_equal expected, wheel.expand
  end

  def test_expand_any_ruby_abi_tag
    wheel = Gem::Platform::Wheel.new("whl-any-linux_x86_64")
    expected = [["any", "linux_x86_64"]]
    assert_equal expected, wheel.expand
  end

  def test_expand_any_platform_tag
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-any")
    expected = [["rb3_cr33", "any"]]
    assert_equal expected, wheel.expand
  end

  def test_equality_same_tags
    wheel1 = Gem::Platform::Wheel.new("whl-rb3_cr33-linux_x86_64")
    wheel2 = Gem::Platform::Wheel.new("whl-rb3_cr33-linux_x86_64")
    assert_equal wheel1, wheel2
    assert wheel1.eql?(wheel2)
    assert_equal wheel1.hash, wheel2.hash
  end

  def test_equality_different_tags
    wheel1 = Gem::Platform::Wheel.new("whl-rb3_cr33-linux_x86_64")
    wheel2 = Gem::Platform::Wheel.new("whl-rb3_cr34-linux_x86_64")
    refute_equal wheel1, wheel2
    refute wheel1.eql?(wheel2)
  end

  def test_equality_different_order_same_content
    wheel1 = Gem::Platform::Wheel.new("whl-rb3_cr33.rb3_cr34-linux_x86_64.linux_aarch64")
    wheel2 = Gem::Platform::Wheel.new("whl-rb3_cr34.rb3_cr33-linux_aarch64.linux_x86_64")
    assert_equal wheel1, wheel2
    assert_equal wheel1.hash, wheel2.hash
  end

  def test_match_operator_with_platform
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-#{normalized_platform}")
    platform = Gem::Platform.new("x86_64-linux")
    assert wheel =~ platform
  end

  def test_match_operator_with_string
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-#{normalized_platform}")
    assert wheel =~ "x86_64-linux"
  end

  def test_case_equality_with_platform
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-#{normalized_platform}")
    platform = Gem::Platform.new("x86_64-linux")
    assert wheel === platform
  end

  def test_case_equality_any_platform_tag
    # Use "any" ruby_abi_tag to match any Ruby environment
    wheel = Gem::Platform::Wheel.new("whl-any-any")
    platform = Gem::Platform.new("x86_64-linux")
    assert wheel === platform
  end

  def test_case_equality_specific_platform_tag
    # Use current ruby_abi_tag but incompatible platform
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-x86_64_linux")
    platform = Gem::Platform.new("aarch64-linux")
    refute wheel === platform
  end

  def test_case_equality_multiple_platform_tags
    # Use current ruby_abi_tag with multiple platform tags
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_x86_linux = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    normalized_aarch64_linux = Gem::Platform::Wheel.normalize_tag_set("aarch64-linux")

    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-#{normalized_aarch64_linux}.#{normalized_x86_linux}")
    platform1 = Gem::Platform.new("x86_64-linux")
    platform2 = Gem::Platform.new("aarch64-linux")
    platform3 = Gem::Platform.new("x86_64-darwin")

    assert wheel === platform1
    assert wheel === platform2
    refute wheel === platform3
  end

  def test_ruby_abi_tag_validation_valid_tags
    valid_tags = %w[rb3_cr33 jr91_1800 tr234_240 any]
    valid_tags.each do |tag|
      wheel = Gem::Platform::Wheel.new("whl-#{tag}-linux_x86_64")
      assert_equal tag, wheel.ruby_abi_tag
    end
  end

  def test_ruby_abi_tag_validation_invalid_tags
    invalid_tags = ["3rb_cr33", "RB3_CR33"]
    invalid_tags.each do |tag|
      assert_raise(ArgumentError) do
        Gem::Platform::Wheel.new("whl-#{tag}-linux_x86_64")
      end
    end
  end

  def test_platform_tag_validation_valid_tags
    valid_tags = %w[linux_x86_64 darwin21_arm64 win32 any musllinux_1_2_x86_64]
    valid_tags.each do |tag|
      wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-#{tag}")
      assert_equal tag, wheel.platform_tags
    end
  end

  def test_platform_tag_validation_invalid_tags
    invalid_tags = ["LINUX"]
    invalid_tags.each do |tag|
      assert_raise(ArgumentError) do
        Gem::Platform::Wheel.new("whl-rb3_cr33-#{tag}")
      end
    end
  end

  def test_tag_normalization_dots_to_underscores
    wheel = Gem::Platform::Wheel.new("whl-rb3.cr33-linux.x86.64")
    assert_equal "cr33.rb3", wheel.ruby_abi_tag
    assert_equal "64.linux.x86", wheel.platform_tags
  end

  def test_tag_normalization_hyphens_to_underscores
    wheel = Gem::Platform::Wheel.new("whl-rb3-cr33-linux-x86-64")
    assert_equal "rb3", wheel.ruby_abi_tag
    assert_equal "cr33_linux_x86_64", wheel.platform_tags
  end

  def test_tag_normalization_sorting
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr34.rb3_cr33-linux_aarch64.linux_x86_64")
    assert_equal "rb3_cr33.rb3_cr34", wheel.ruby_abi_tag
    assert_equal "linux_aarch64.linux_x86_64", wheel.platform_tags
  end

  def test_tag_normalization_deduplication
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33.rb3_cr33-linux_x86_64.linux_x86_64")
    assert_equal "rb3_cr33", wheel.ruby_abi_tag
    assert_equal "linux_x86_64", wheel.platform_tags
  end

  def test_normalize_platform_tags_empty
    assert_equal "any", Gem::Platform::Wheel.normalize_tag_set("")
    assert_equal "any", Gem::Platform::Wheel.normalize_tag_set(nil)
  end

  def test_normalize_platform_tags_single
    assert_equal "64.linux_x86", Gem::Platform::Wheel.normalize_tag_set("linux-x86.64")
  end

  def test_normalize_platform_tags_multiple
    result = Gem::Platform::Wheel.normalize_tag_set("linux-x86.64.darwin.arm64")
    assert_equal "64.arm64.darwin.linux_x86", result
  end

  # Test interactions between wheel and traditional platforms
  def test_wheel_vs_traditional_platform_equality
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-x86_64_linux")
    traditional = Gem::Platform.new("x86_64-linux")

    # Wheels and traditional platforms should never be equal
    refute_equal wheel, traditional
    refute_equal traditional, wheel
    refute wheel.eql?(traditional)
    refute traditional.eql?(wheel)
  end

  def test_wheel_matches_traditional_platform_via_case_equality
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-#{normalized_platform}")
    traditional = Gem::Platform.new("x86_64-linux")

    # Wheel should match traditional platform (wheel can run on traditional)
    assert wheel === traditional

    # Traditional platform should NOT match wheel (traditional gem can't run on wheel platform)
    refute traditional === wheel
  end

  def test_wheel_any_tag_matches_all_traditional_platforms
    # Use "any" for both ruby_abi_tag and platform_tags
    wheel = Gem::Platform::Wheel.new("whl-any-any")
    platforms = [
      Gem::Platform.new("x86_64-linux"),
      Gem::Platform.new("aarch64-linux"),
      Gem::Platform.new("x86_64-darwin"),
      Gem::Platform.new("arm64-darwin"),
      Gem::Platform.new("x64-mingw-ucrt"),
    ]

    platforms.each do |platform|
      assert wheel === platform, "Wheel with 'any' tags should match #{platform}"
    end
  end

  def test_wheel_specific_platform_only_matches_compatible
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_x86_linux = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-#{normalized_x86_linux}")

    # Should match
    assert wheel === Gem::Platform.new("x86_64-linux")

    # Should not match
    refute wheel === Gem::Platform.new("aarch64-linux")
    refute wheel === Gem::Platform.new("x86_64-darwin")
    refute wheel === Gem::Platform.new("x64-mingw-ucrt")
  end

  def test_wheel_platform_normalization_matches_traditional
    # Test that platform tag normalization allows matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    wheel = Gem::Platform::Wheel.new("whl-#{current_abi}-x86_64_linux")
    traditional = Gem::Platform.new("x86_64-linux")

    # Should match with normalized platform tags
    assert wheel === traditional
  end

  def test_multiple_ruby_abi_tags_irrelevant_for_traditional_matching
    # Test multiple ruby_abi_tags where one matches current environment
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform::Wheel.new("whl-rb3_cr33.#{current_abi}-#{normalized_platform}")
    traditional = Gem::Platform.new("x86_64-linux")

    # Should match because one of the ruby_abi_tags matches
    assert wheel === traditional
  end

  def test_wheel_design_ruby_abi_format
    # Test the design decision for Ruby/ABI tag format: {engine}{version}_{abi}
    valid_formats = [
      "cr33_220",    # CRuby 3.3, ABI 220
      "jr91_1800",   # JRuby 9.1, Java 18.0.0
      "tr234_240",   # TruffleRuby 23.4, ABI 240
      "rb3_cr33",    # Alternative format
      "any", # Universal wildcard
    ]

    valid_formats.each do |format|
      wheel = Gem::Platform::Wheel.new("whl-#{format}-x86_64_linux")
      assert_equal format, wheel.ruby_abi_tag
    end
  end

  def test_wheel_design_platform_tag_normalization
    # Test the design decision for tag normalization
    test_cases = {
      "linux-x86.64" => "64.linux_x86",
      "linux_x86_64" => "linux_x86_64", # No change needed
      "x86-64.linux" => "linux.x86_64",
      "x86_64.linux" => "linux.x86_64",
    }

    test_cases.each do |input, expected|
      wheel = Gem::Platform::Wheel.new("whl-rb3_cr33-#{input}")
      assert_equal expected, wheel.platform_tags,
        "Input '#{input}' should normalize to '#{expected}'"
    end
  end

  def test_wheel_design_backward_compatibility
    # Ensure wheel platforms don't interfere with existing platform functionality
    traditional_strings = [
      "ruby",
      "x86_64-linux",
      "universal-darwin",
      "java",
      "x64-mingw-ucrt",
    ]

    traditional_strings.each do |platform_string|
      platform = Gem::Platform.new(platform_string)
      refute platform.is_a?(Gem::Platform::Wheel),
        "Traditional platform '#{platform_string}' should not create Wheel instance"
    end
  end

  # Tests moved from test_gem_platform.rb

  def test_initialize_wheel
    platform = Gem::Platform.new("whl-rb3.cr33-musllinux_1_2_x86_64")
    assert_equal [["cr33", "musllinux_1_2_x86_64"], ["rb3", "musllinux_1_2_x86_64"]], platform.expand
    assert_equal "whl-cr33.rb3-musllinux_1_2_x86_64", platform.to_s
  end

  def test_platform_new_with_wheel_instance
    wheel = Gem::Platform::Wheel.new("whl-rb3.cr33-linux_x86_64")
    platform = Gem::Platform.new(wheel)
    refute_same wheel, platform
    assert_equal wheel, platform
  end

  def test_wheel_platform_matching
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel = Gem::Platform.new("whl-#{current_abi}-#{normalized_platform}")
    traditional = Gem::Platform.new("x86_64-linux")

    # Wheel should match traditional platform
    assert wheel === traditional

    # Traditional platform should not match wheel
    refute traditional === wheel
  end

  def test_wheel_platform_sorting
    wheel1 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux")
    wheel2 = Gem::Platform.new("whl-rb3.cr34-x86_64_linux")
    traditional = Gem::Platform.new("x86_64-linux")

    specs = [
      util_spec("test", "1.0") {|s| s.platform = traditional },
      util_spec("test", "1.0") {|s| s.platform = wheel2 },
      util_spec("test", "1.0") {|s| s.platform = wheel1 },
    ]

    # Test with Ruby 3.3 environment - wheel1 (cr33) should match best
    target_platform = Gem::Platform::Specific.new(traditional, ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    sorted_specs = Gem::Platform.sort_best_platform_match(specs, target_platform)
    assert_equal [wheel1, traditional, wheel2], sorted_specs.map(&:platform)

    # Test with Ruby 3.4 environment - wheel2 (cr34) should match best
    target_platform = Gem::Platform::Specific.new(traditional, ruby_engine: "ruby", ruby_engine_version: "3.4.0", ruby_version: "3.4.0", abi_version: "3.4.0")
    sorted_specs = Gem::Platform.sort_best_platform_match(specs, target_platform)
    assert_equal [wheel2, traditional, wheel1], sorted_specs.map(&:platform)
  end

  def test_match_platforms_wheel_vs_traditional
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    wheel_platform = Gem::Platform.new("whl-#{current_abi}-#{normalized_platform}")
    traditional_platform = Gem::Platform.new("x86_64-linux")
    ruby_platform = Gem::Platform::RUBY

    # Test wheel platform against various user platforms
    user_platforms = [traditional_platform, ruby_platform]

    # Wheel should match traditional and ruby platforms
    assert Gem::Platform.send(:match_platforms?, wheel_platform, user_platforms)

    # Traditional should NOT match wheel platform
    refute Gem::Platform.send(:match_platforms?, traditional_platform, [wheel_platform])

    # But traditional should match itself and ruby
    assert Gem::Platform.send(:match_platforms?, traditional_platform, user_platforms)
  end

  def test_match_spec_with_wheel_platforms
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")

    wheel_spec = util_spec "wheel-gem", "1.0" do |s|
      s.platform = Gem::Platform.new("whl-#{current_abi}-#{normalized_platform}")
    end

    traditional_spec = util_spec "traditional-gem", "1.0" do |s|
      s.platform = Gem::Platform.new("x86_64-linux")
    end

    ruby_spec = util_spec "ruby-gem", "1.0" do |s|
      s.platform = Gem::Platform::RUBY
    end

    # Set current platforms to traditional
    platforms = Gem.platforms
    Gem.platforms = [Gem::Platform.new("x86_64-linux"), Gem::Platform::RUBY]

    begin
      # Wheel should match current platforms (wheel can run on traditional)
      assert Gem::Platform.match_spec?(wheel_spec)

      # Traditional should match
      assert Gem::Platform.match_spec?(traditional_spec)

      # Ruby should match
      assert Gem::Platform.match_spec?(ruby_spec)
    ensure
      Gem.platforms = platforms
    end
  end

  def test_match_gem_with_wheel_platforms
    # Test wheel gems vs traditional user platforms
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")

    platforms = Gem.platforms
    Gem.platforms = [Gem::Platform.new("x86_64-linux"), Gem::Platform::RUBY]

    begin
      assert Gem::Platform.match_gem?("whl-#{current_abi}-#{normalized_platform}", "some-gem")
      assert Gem::Platform.match_gem?("x86_64-linux", "some-gem")
      assert Gem::Platform.match_gem?(Gem::Platform::RUBY, "some-gem")
    ensure
      Gem.platforms = platforms
    end
  end

  def test_installable_with_wheel_platforms
    # Use current ruby_abi_tag for proper matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")

    wheel_spec = util_spec "wheel-gem", "1.0" do |s|
      s.platform = Gem::Platform.new("whl-#{current_abi}-#{normalized_platform}")
    end

    traditional_spec = util_spec "traditional-gem", "1.0" do |s|
      s.platform = Gem::Platform.new("x86_64-linux")
    end

    platforms = Gem.platforms
    Gem.platforms = [Gem::Platform.new("x86_64-linux"), Gem::Platform::RUBY]

    begin
      # Both should be installable on traditional platforms
      assert Gem::Platform.installable?(wheel_spec)
      assert Gem::Platform.installable?(traditional_spec)
    ensure
      Gem.platforms = platforms
    end
  end

  def test_sort_priority_wheel_vs_traditional
    wheel_platform = Gem::Platform.new("whl-rb3.cr33-x86_64_linux")
    traditional_platform = Gem::Platform.new("x86_64-linux")
    ruby_platform = Gem::Platform::RUBY

    # Ruby should have lowest priority (most preferred)
    assert_equal(-1, Gem::Platform.sort_priority(ruby_platform))

    # Wheel platforms should have higher priority than traditional platforms
    assert_equal 2, Gem::Platform.sort_priority(wheel_platform)
    assert_equal 1, Gem::Platform.sort_priority(traditional_platform)
  end

  def test_platform_specificity_cross_platform_types
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    current_platform = Gem::Platform.local
    normalized_platform = Gem::Platform::Wheel.normalize_tag_set(current_platform.to_s)

    # Use a different ruby abi to ensure wheel doesn't match perfectly
    test_abi = current_abi == "cr33" ? "cr34" : "cr33"
    wheel_platform = Gem::Platform.new("whl-#{test_abi}-#{normalized_platform}")
    traditional_platform = current_platform
    user_platform = current_platform

    wheel_specificity = Gem::Platform.platform_specificity_match(wheel_platform, user_platform)
    traditional_specificity = Gem::Platform.platform_specificity_match(traditional_platform, user_platform)

    # Traditional platform should be more specific for traditional user platform when wheel doesn't match Ruby ABI
    assert traditional_specificity < wheel_specificity,
      "Traditional platform should be more specific than wheel for traditional user platform when wheel Ruby ABI doesn't match"
  end

  def test_sort_and_filter_best_platform_match_mixed_types
    wheel1 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux")
    wheel2 = Gem::Platform.new("whl-rb3_cr34-x86_64_linux")
    traditional = Gem::Platform.new("x86_64-linux")
    ruby = Gem::Platform::RUBY

    specs = [
      util_spec("gem", "1.0") {|s| s.platform = wheel1 },
      util_spec("gem", "1.0") {|s| s.platform = wheel2 },
      util_spec("gem", "1.0") {|s| s.platform = traditional },
      util_spec("gem", "1.0") {|s| s.platform = ruby },
    ]

    user_platform = Gem::Platform.new("x86_64-linux")
    filtered = Gem::Platform.sort_and_filter_best_platform_match(specs, user_platform)

    # Should prioritize traditional platform for traditional user
    assert_equal traditional, filtered.first.platform

    # Should include ruby platform as well (same specificity)
    platform_types = filtered.map {|s| s.platform.class }.uniq
    assert_includes platform_types, Gem::Platform
  end

  def test_match_wheel_with_current_environment
    # Create a wheel that matches current environment
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    current_platform = Gem::Platform.local
    platform_tag = Gem::Platform::Wheel.normalize_tag_set(current_platform.to_s)

    matching_wheel = Gem::Platform.new("whl-#{current_abi}-#{platform_tag}")

    # Should match when explicitly specifying current environment
    assert matching_wheel.send(:match?, ruby_abi_tag: current_abi, platform: current_platform),
      "Wheel matching current environment should match"
  end

  def test_match_wheel_with_different_ruby_abi
    current_platform = Gem::Platform.local
    platform_tag = Gem::Platform::Wheel.normalize_tag_set(current_platform.to_s)

    # Create wheel with different Ruby ABI
    different_abi_wheel = Gem::Platform.new("whl-jr91_1800-#{platform_tag}")

    # Should not match current environment
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    refute different_abi_wheel.send(:match?, ruby_abi_tag: current_abi, platform: current_platform),
      "Wheel with different Ruby ABI should not match current environment"
  end

  def test_match_wheel_with_any_tags
    # Test wheel with "any" ruby_abi_tag
    any_abi_wheel = Gem::Platform.new("whl-any-x86_64_linux")
    linux_platform = Gem::Platform.new("x86_64-linux")

    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    assert any_abi_wheel.send(:match?, ruby_abi_tag: current_abi, platform: linux_platform),
      "Wheel with 'any' ruby_abi_tag should match any Ruby environment"

    # Test wheel with "any" platform_tags
    any_platform_wheel = Gem::Platform.new("whl-#{current_abi}-any")

    assert any_platform_wheel.send(:match?, ruby_abi_tag: current_abi, platform: linux_platform),
      "Wheel with 'any' platform_tags should match any platform"
  end

  def test_match_wheel_tuple_based_matching
    # Test explicit ruby_abi_tag and platform specification
    wheel = Gem::Platform.new("whl-cr33_220-x86_64_linux")
    platform = Gem::Platform.new("x86_64-linux")

    # Should match when explicitly specified matching values
    assert wheel.send(:match?, ruby_abi_tag: "cr33_220", platform: platform),
      "Should match when ruby_abi_tag and platform are explicitly compatible"

    # Should not match when ruby_abi_tag differs
    refute wheel.send(:match?, ruby_abi_tag: "jr91_1800", platform: platform),
      "Should not match when ruby_abi_tag differs"

    # Should not match when platform differs
    darwin_platform = Gem::Platform.new("x86_64-darwin")
    refute wheel.send(:match?, ruby_abi_tag: "cr33_220", platform: darwin_platform),
      "Should not match when platform differs"
  end

  def test_match_wheel_with_specific_instance
    # Test new Specific-based API
    wheel = Gem::Platform.new("whl-cr33-x86_64_linux")
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    assert wheel.send(:match?, specific),
      "Wheel should match compatible Specific instance"

    # Test with incompatible specific
    incompatible_specific = Gem::Platform::Specific.new("aarch64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    refute wheel.send(:match?, incompatible_specific),
      "Wheel should not match incompatible Specific instance"
  end

  def test_match_wheel_with_current_specific
    # Test using current environment
    current_specific = Gem::Platform::Specific.local
    # Generate ABI tag from the Specific object to ensure compatibility
    generated_abi = Gem::Platform::Specific.generate_ruby_abi_tag(
      current_specific.ruby_engine,
      current_specific.ruby_engine_version,
      current_specific.ruby_version,
      current_specific.abi_version
    )
    current_platform_tag = Gem::Platform::Wheel.normalize_tag_set(Gem::Platform.local.to_s)

    wheel = Gem::Platform.new("whl-#{generated_abi}-#{current_platform_tag}")

    assert wheel.send(:match?, current_specific),
      "Wheel should match current environment via Specific"
  end

  def test_match_wheel_specific_vs_keyword_arguments
    # Test that both APIs produce same results
    wheel = Gem::Platform.new("whl-cr33-x86_64_linux")
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    result_specific = wheel.send(:match?, specific)
    result_keywords = wheel.send(:match?, ruby_abi_tag: "cr33", platform: Gem::Platform.new("x86_64-linux"))

    assert_equal result_specific, result_keywords,
      "Both APIs should produce same matching result"
  end

  def test_match_wheel_error_handling_with_specific
    wheel = Gem::Platform.new("whl-cr33-x86_64_linux")
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    # Test error when providing both specific and keyword arguments
    assert_raise(ArgumentError, "Should raise error when mixing specific and keywords") do
      wheel.send(:match?, specific, ruby_abi_tag: "cr33")
    end

    # Test error when providing wrong type for specific
    assert_raise(ArgumentError, "Should raise error for wrong specific type") do
      wheel.send(:match?, "not-a-specific")
    end

    # Test error when providing neither
    assert_raise(ArgumentError, "Should raise error when no parameters provided") do
      wheel.send(:match?)
    end
  end

  def test_generate_ruby_abi_tag
    # Test the new ruby ABI tag generation method with abi_version
    # With standard abi_version (3.3.0), no suffix is added since it matches major.minor.0
    tag = Gem::Platform::Specific.generate_ruby_abi_tag("ruby", "3.3.1", "3.3.1", "3.3.0")
    assert_equal "cr33", tag

    # With abi_version that has suffix (like static build)
    tag = Gem::Platform::Specific.generate_ruby_abi_tag("ruby", "3.3.1", "3.3.1", "3.3.0-static")
    assert_equal "cr33_static", tag

    # JRuby with standard abi_version
    tag = Gem::Platform::Specific.generate_ruby_abi_tag("jruby", "9.4.0", "3.1.0", "3.1.0")
    assert_equal "jr94", tag

    # Test fallback to ruby_version when abi_version is nil - extracts suffix after major.minor.0
    tag = Gem::Platform::Specific.generate_ruby_abi_tag("ruby", "3.3.1", "3.3.1", nil)
    assert_equal "cr33_1", tag

    # Test fallback to current when missing info
    tag = Gem::Platform::Specific.generate_ruby_abi_tag(nil, nil, nil, nil)
    assert_nil tag

    tag = Gem::Platform::Specific.generate_ruby_abi_tag("ruby", nil, "3.3.1", "3.3.0")
    assert_nil tag
  end

  def test_wheel_case_equality_uses_tuple_matching
    # Test that wheel === platform uses the new tuple matching
    current_abi = Gem::Platform::Specific.current_ruby_abi_tag
    current_platform = Gem::Platform.local
    platform_tag = Gem::Platform::Wheel.normalize_tag_set(current_platform.to_s)

    matching_wheel = Gem::Platform.new("whl-#{current_abi}-#{platform_tag}")

    # Should match current platform
    assert matching_wheel === current_platform,
      "Wheel should match compatible traditional platform via case equality"

    # Create incompatible wheel
    incompatible_wheel = Gem::Platform.new("whl-jr91_1800-x86_64_darwin")
    refute incompatible_wheel === current_platform,
      "Incompatible wheel should not match traditional platform"
  end

  def test_wheel_platform_tag_validation_integration
    assert Gem::Platform.new("whl-rb3.cr33-linux_x86_64")
    assert Gem::Platform.new("whl-rb3.cr33-mingw_x86_64")
    assert Gem::Platform.new("whl-rb3.cr33-darwin_x86_64")
    assert Gem::Platform.new("whl-rb3.cr33-linux_x86_64_musl")
  end

  def test_wheel_platform_string_variations_integration
    # Test various wheel platform string formats
    assert_equal "whl-cr33.rb3-x86_64_linux", Gem::Platform.new("whl-rb3.cr33-x86_64_linux").to_s
    assert_equal "whl-cr33.rb3-x86_64_linux_musl", Gem::Platform.new("whl-rb3.cr33-x86_64_linux_musl").to_s
    assert_equal "whl-cr33.rb3-x86_64_darwin", Gem::Platform.new("whl-rb3.cr33-x86_64_darwin").to_s
    assert_equal "whl-cr33.rb3-arm64_darwin", Gem::Platform.new("whl-rb3.cr33-arm64_darwin").to_s
    assert_equal "whl-any-any", Gem::Platform.new("whl-any-any").to_s
    assert_equal "whl-rb3-any", Gem::Platform.new("whl-rb3-any").to_s
    assert_equal "whl-any-x86_64_linux", Gem::Platform.new("whl-any-x86_64_linux").to_s
  end

  def test_wheel_platform_equality_integration
    # Test == operator
    p1 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux")
    p2 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux")
    p3 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux_musl")
    p4 = Gem::Platform.new("x86_64-linux")

    assert_equal p1, p1
    assert_equal p1, p2
    refute_equal p1, p3
    refute_equal p1, p4

    # Test hash method
    assert_equal p1.hash, p2.hash
    refute_equal p1.hash, p3.hash
    refute_equal p1.hash, p4.hash

    # Test to_a method
    assert_equal ["whl", "cr33.rb3", "x86_64_linux"], p1.to_a
    assert_equal ["whl", "cr33.rb3", "x86_64_linux_musl"], p3.to_a
    assert_equal ["x86_64", "linux", nil], p4.to_a

    # Test with mixed platform formats
    p5 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux.x86_64_linux")
    p6 = Gem::Platform.new("whl-rb3.cr33-x86_64_linux.x86_64_darwin")

    assert_equal p1, p5
    refute_equal p1, p6
    assert_equal p1.hash, p5.hash
    refute_equal p1.hash, p6.hash
  end

  def test_wheel_basics_integration
    linux = Gem::Platform.new("whl-any-x86_64_linux")

    assert Gem::Platform.send(:match_platforms?, linux, [Gem::Platform.new("x86_64-linux")]),
      "expected #{linux} to match [x86_64-linux]"
    # assert Gem::Platform.send(:match_platforms?, linux, [Gem::Platform.new("x86_64-linux-20")]),
    #   "expected #{linux} to match [x86_64-linux-20]"
    refute Gem::Platform.send(:match_platforms?, linux, [Gem::Platform.new("x86_64-darwin")]),
      "expected #{linux} to not match [x86_64-darwin]"
  end

  def test_normalize_platform_tags_integration
    # Test legacy platform tags
    assert_equal "x86_64_linux", Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    assert_equal "x86_64_linux_musl", Gem::Platform::Wheel.normalize_tag_set("x86_64-linux-musl")
    assert_equal "x86_64_darwin", Gem::Platform::Wheel.normalize_tag_set("x86_64-darwin")
    assert_equal "arm64_darwin", Gem::Platform::Wheel.normalize_tag_set("arm64-darwin")

    # Test wheel platform tags
    assert_equal "x86_64_linux", Gem::Platform::Wheel.normalize_tag_set("x86_64-linux")
    assert_equal "x86_64_linux_musl", Gem::Platform::Wheel.normalize_tag_set("x86_64-linux-musl")
    assert_equal "x86_64_darwin", Gem::Platform::Wheel.normalize_tag_set("x86_64-darwin")
    assert_equal "arm64_darwin", Gem::Platform::Wheel.normalize_tag_set("arm64-darwin")

    # Test mixed platform formats
    assert_equal "x86_64_linux", Gem::Platform::Wheel.normalize_tag_set("x86_64-linux.x86_64-linux")
    assert_equal "x86_64_darwin.x86_64_linux", Gem::Platform::Wheel.normalize_tag_set("x86_64-linux.x86_64-darwin")
  end

  def test_platform_specificity_match_wheel_vs_specific_integration
    # Test wheel vs Specific object matching - should use full Specific environment details
    wheel = Gem::Platform.new("whl-cr33-x86_64_linux")
    specific_compatible = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific_incompatible = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.2.0", ruby_version: "3.2.0", abi_version: "3.2.0")

    # Compatible Specific should match with wheel specificity (-5 to -3 range)
    specificity_match = Gem::Platform.platform_specificity_match(wheel, specific_compatible)
    assert_equal(-10, specificity_match, "#{wheel} to #{specific_compatible}")

    # Incompatible Specific should not match
    specificity_no_match = Gem::Platform.platform_specificity_match(wheel, specific_incompatible)
    assert_equal 1_000_000, specificity_no_match, "Incompatible Specific should not match wheel"
  end

  def test_platform_specificity_match_wheel_vs_traditional_integration
    # Test wheel vs traditional platform - should use current environment fallback

    wheel = Gem::Platform.new("whl-#{Gem::Platform::Specific.current_ruby_abi_tag}-x86_64_linux")
    traditional = Gem::Platform.new("x86_64-linux")

    # Should use wheel matching logic with current environment, returning -10 for exact match
    specificity = Gem::Platform.platform_specificity_match(wheel, traditional)
    assert_equal(-10, specificity, "Gem::Platform.platform_specificity_match(#{wheel}, #{traditional})")
  end
end
