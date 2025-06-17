# frozen_string_literal: true

require_relative "helper"
require "rubygems/platform"

class TestGemPlatformSpecific < Gem::TestCase
  def test_initialize_with_platform_object
    platform = Gem::Platform.new("x86_64-linux")
    specific = Gem::Platform::Specific.new(platform, ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    assert_equal platform, specific.platform
    assert_equal "ruby", specific.ruby_engine
    assert_equal "3.3.1", specific.ruby_engine_version
    assert_equal "3.3.1", specific.ruby_version
    assert_equal "3.3.0", specific.abi_version
  end

  def test_initialize_with_platform_string
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    assert_equal Gem::Platform.new("x86_64-linux"), specific.platform
    assert_equal "ruby", specific.ruby_engine
    assert_equal "3.3.1", specific.ruby_engine_version
    assert_equal "3.3.1", specific.ruby_version
    assert_equal "3.3.0", specific.abi_version
  end

  def test_initialize_with_minimal_parameters
    specific = Gem::Platform::Specific.new("x86_64-linux")

    assert_equal Gem::Platform.new("x86_64-linux"), specific.platform
    assert_nil specific.ruby_engine
    assert_nil specific.ruby_engine_version
    assert_nil specific.ruby_version
    assert_nil specific.abi_version
  end

  def test_to_s_full_specification
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    expected = "x86_64-linux v:1 engine:ruby engine_version:3.3.1 ruby_version:3.3.1 abi_version:3.3.0"
    assert_equal expected, specific.to_s
  end

  def test_to_s_partial_specification
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_version: "3.3.1", abi_version: "3.3.0")
    expected = "x86_64-linux v:1 engine:ruby ruby_version:3.3.1 abi_version:3.3.0"
    assert_equal expected, specific.to_s
  end

  def test_to_s_platform_only
    specific = Gem::Platform::Specific.new("x86_64-linux")
    expected = "x86_64-linux v:1"
    assert_equal expected, specific.to_s
  end

  def test_inspect
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    result = specific.inspect

    assert_match(/^#<Gem::Platform::Specific:0x/, result)
    assert_match(/platform=#<Gem::Platform/, result)
    assert_match(/ruby_engine="ruby"/, result)
    assert_match(/ruby_engine_version="3.3.1"/, result)
    assert_match(/ruby_version="3.3.1"/, result)
    assert_match(/abi_version="3.3.0"/, result)
  end

  def test_equality_same_values
    specific1 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific2 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    assert_equal specific1, specific2
    assert specific1.eql?(specific2)
    assert_equal specific1.hash, specific2.hash
  end

  def test_equality_different_platforms
    specific1 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific2 = Gem::Platform::Specific.new("aarch64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    refute_equal specific1, specific2
    refute specific1.eql?(specific2)
  end

  def test_equality_different_ruby_engines
    specific1 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific2 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "jruby", ruby_engine_version: "9.4.0", ruby_version: "3.1.0", abi_version: "3.1.0")

    refute_equal specific1, specific2
    refute specific1.eql?(specific2)
  end

  def test_equality_different_abi_versions
    specific1 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific2 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.2.0")

    refute_equal specific1, specific2
    refute specific1.eql?(specific2)
  end

  def test_equality_nil_vs_missing
    specific1 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: nil)
    specific2 = Gem::Platform::Specific.new("x86_64-linux")

    assert_equal specific1, specific2
    assert specific1.eql?(specific2)
  end

  def test_current_class_method
    current = Gem::Platform::Specific.local

    assert_equal Gem::Platform.local, current.platform
    assert_equal RUBY_ENGINE, current.ruby_engine
    assert_equal RUBY_ENGINE_VERSION, current.ruby_engine_version
    assert_equal RUBY_VERSION, current.ruby_version
    assert_equal Gem.extension_api_version, current.abi_version
  end

  def test_current_creates_different_instances
    current1 = Gem::Platform::Specific.local
    current2 = Gem::Platform::Specific.local

    assert_equal current1, current2
    refute_same current1, current2
  end

  def test_hash_consistency
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    # Hash should be consistent across calls
    hash1 = specific.hash
    hash2 = specific.hash
    assert_equal hash1, hash2

    # Hash should be based on content
    duplicate = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    assert_equal specific.hash, duplicate.hash
  end

  def test_works_as_hash_key
    specific1 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific2 = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific3 = Gem::Platform::Specific.new("aarch64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    hash = { specific1 => "value1", specific3 => "value3" }

    assert_equal "value1", hash[specific1]
    assert_equal "value1", hash[specific2] # Should find same key due to equality
    assert_equal "value3", hash[specific3]
    assert_nil hash[Gem::Platform::Specific.new("x86_64-darwin")]
  end

  # Tests moved from test_gem_platform.rb

  def test_self_current_ruby_abi_tag_includes_extension_api_version
    # Test that current_ruby_abi_tag returns the same result as generate_ruby_abi_tag with current environment
    current_abi_tag = Gem::Platform::Specific.local.ruby_abi_tag
    expected_abi_tag = Gem::Platform::Specific.generate_ruby_abi_tag(
      RUBY_ENGINE,
      RUBY_ENGINE_VERSION,
      RUBY_VERSION,
      Gem.extension_api_version
    )

    assert_equal expected_abi_tag, current_abi_tag,
      "current_ruby_abi_tag should match generate_ruby_abi_tag for current environment"
  end

  def test_generate_ruby_abi_tag_integration
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

  def test_platform_specificity_match_integration
    [
      ["ruby", "ruby", -1, -1],
      ["x86_64-linux-musl", "x86_64-linux-musl", -1, -1],
      ["x86_64-linux", "x86_64-linux-musl", 100, 200],
      ["universal-darwin", "x86-darwin", 10, 20],
      ["universal-darwin-19", "x86-darwin", 210, 120],
      ["universal-darwin-19", "universal-darwin-20", 200, 200],
      ["arm-darwin-19", "arm64-darwin-19", 0, 20],
    ].each do |spec_platform, user_platform, s1, s2|
      spec_platform = Gem::Platform.new(spec_platform)
      user_platform = Gem::Platform.new(user_platform)
      assert_equal s1, Gem::Platform.platform_specificity_match(spec_platform, user_platform),
        "Gem::Platform.platform_specificity_match(#{spec_platform.to_s.inspect}, #{user_platform.to_s.inspect})"
      assert_equal s2, Gem::Platform.platform_specificity_match(user_platform, spec_platform),
        "Gem::Platform.platform_specificity_match(#{user_platform.to_s.inspect}, #{spec_platform.to_s.inspect})"
    end
  end

  def test_platform_specificity_match_traditional_vs_specific
    # Test traditional vs Specific - should extract platform for standard matching
    traditional = Gem::Platform.new("x86_64-linux")
    specific_same = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")
    specific_different = Gem::Platform::Specific.new("aarch64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    # Same platform should be perfect match
    specificity_same = Gem::Platform.platform_specificity_match(traditional, specific_same)
    assert_equal(-1, specificity_same, "Traditional vs same Specific platform should be perfect match (-1)")

    # Different platform should use standard platform matching
    specificity_different = Gem::Platform.platform_specificity_match(traditional, specific_different)
    assert specificity_different > 0, "Traditional vs different Specific platform should have positive specificity"
  end

  def test_platform_specificity_match_edge_cases
    # Test edge cases and special platforms
    ruby_platform = Gem::Platform::RUBY
    specific = Gem::Platform::Specific.new("x86_64-linux", ruby_engine: "ruby", ruby_engine_version: "3.3.1", ruby_version: "3.3.1", abi_version: "3.3.0")

    # Ruby platform should return 1_000_000 for anything
    specificity_ruby_specific = Gem::Platform.platform_specificity_match(ruby_platform, specific)
    assert_equal 1_000_000, specificity_ruby_specific, "Ruby platform should return 1_000_000"

    specificity_specific_ruby = Gem::Platform.platform_specificity_match(specific, ruby_platform)
    assert_equal 1_000_000, specificity_specific_ruby, "Anything vs Ruby platform should return 1_000_000"

    # Nil platform should return 1_000_000
    specificity_nil = Gem::Platform.platform_specificity_match(nil, specific)
    assert_equal 1_000_000, specificity_nil, "Nil platform should return 1_000_000"
  end

  def test_tags_rb_version_range
    # Test with different ruby versions
    specific_331 = Gem::Platform::Specific.new("ruby", ruby_version: "3.3.1")
    assert_equal ["rb33", "rb3", "rb32", "rb31", "rb30"], specific_331.send(:_rb_version_range).to_a

    specific_33 = Gem::Platform::Specific.new("ruby", ruby_version: "3.3")
    assert_equal ["rb33", "rb3", "rb32", "rb31", "rb30"], specific_33.send(:_rb_version_range).to_a

    specific_3 = Gem::Platform::Specific.new("ruby", ruby_version: "3")
    assert_equal ["rb3"], specific_3.send(:_rb_version_range).to_a

    specific_40 = Gem::Platform::Specific.new("ruby", ruby_version: "4.0")
    assert_equal ["rb40", "rb4"], specific_40.send(:_rb_version_range).to_a
  end

  def test_tags_compatible_tags
    # Create a Specific instance with ruby version 3.3.1
    specific = Gem::Platform::Specific.new("ruby", ruby_version: "3.3.1")
    assert_equal [
      ["rb33", "any"],
      ["rb3", "any"],
      ["rb32", "any"],
      ["rb31", "any"],
      ["rb30", "any"],
    ],
                 specific.compatible_tags.to_a
  end

  def test_tags_platform_tags
    do_test = ->(platform, expected) {
      platform = Gem::Platform.new(platform)
      specific = Gem::Platform::Specific.new(platform)
      expected.each do |a|
        pl = Gem::Platform.new(a)
        assert_equal a, pl.to_s, "#{pl.inspect}.to_s"
        assert platform === pl, "#{platform.inspect} === #{pl.inspect}"
      end
      actual = specific._platform_tags.to_a
      assert_equal(expected, actual, "_platform_tags(#{platform.inspect})")
    }

    do_test.call("ruby", [])
    do_test.call("arm64-darwin-23",["arm64-darwin-23",
                                    "universal-darwin-23",
                                    "arm64-darwin",
                                    "universal-darwin",
                                    "darwin"])
    do_test.call("aarch64-darwin", %w[aarch64-darwin universal-darwin darwin])
    do_test.call("universal-darwin-23", %w[universal-darwin-23 universal-darwin darwin])
    do_test.call("universal-darwin", %w[universal-darwin darwin])
    do_test.call("java", %w[java universal-java])
    do_test.call("universal-java", %w[universal-java java])
    do_test.call("universal-java-1.6", %w[universal-java-1.6 universal-java java])
    do_test.call("arm-java", %w[arm-java universal-java java])

    do_test.call("x86-linux", ["x86-linux", "universal-linux"])
    do_test.call("x86_64-linux-musl", ["x86_64-linux-musl", "universal-linux-musl"])

    do_test.call("x86-mingw32", ["x86-mingw32", "universal-mingw32", "mingw32"])

    do_test.call("x86_64-linux-android", ["x86_64-linux-android", "universal-linux-android"])
  end

  def test_specific_all_tags
    do_test = ->(platform, expected:, **kwargs) {
      platform = Gem::Platform.new(platform)
      specific = Gem::Platform::Specific.new(platform, **kwargs)

      expected.each do |rb, pl|
        whl = Gem::Platform.new("whl-#{rb}-#{pl}")
        assert whl === specific, "#{whl} === #{specific}"
      end
      actual = specific.each_possible_match.to_a

      assert_empty(actual.tally.select {|_, v| v > 1 }, "no duplicate tags should be generated")

      assert_equal expected, specific.each_possible_match.to_a
    }

    do_test.call("ruby", expected: [%w[any any]])
    do_test.call("arm64-darwin-24", abi_version: "3.4.0-static", ruby_engine: "ruby", ruby_engine_version: "3.4.4", ruby_version: "3.4.4", expected: [
      %w[cr34_static arm64_darwin_24], %w[cr34_static universal_darwin_24], %w[cr34_static arm64_darwin], %w[cr34_static universal_darwin], %w[cr34_static darwin],
      %w[rb34 arm64_darwin_24], %w[rb34 universal_darwin_24], %w[rb34 arm64_darwin], %w[rb34 universal_darwin], %w[rb34 darwin],
      %w[rb3 arm64_darwin_24], %w[rb3 universal_darwin_24], %w[rb3 arm64_darwin], %w[rb3 universal_darwin], %w[rb3 darwin],
      %w[rb33 arm64_darwin_24], %w[rb33 universal_darwin_24], %w[rb33 arm64_darwin], %w[rb33 universal_darwin], %w[rb33 darwin],
      %w[rb32 arm64_darwin_24], %w[rb32 universal_darwin_24], %w[rb32 arm64_darwin], %w[rb32 universal_darwin], %w[rb32 darwin],
      %w[rb31 arm64_darwin_24], %w[rb31 universal_darwin_24], %w[rb31 arm64_darwin], %w[rb31 universal_darwin], %w[rb31 darwin],
      %w[rb30 arm64_darwin_24], %w[rb30 universal_darwin_24], %w[rb30 arm64_darwin], %w[rb30 universal_darwin], %w[rb30 darwin],
      %w[rb34 any], %w[rb3 any], %w[rb33 any], %w[rb32 any], %w[rb31 any], %w[rb30 any],
      %w[any arm64_darwin_24], %w[any universal_darwin_24], %w[any arm64_darwin], %w[any universal_darwin], %w[any darwin],
      %w[any any]
    ])
  end

  def test_tags_extract_abi_suffix
    assert_equal "static", Gem::Platform::Specific.send(:extract_abi_suffix, "3.4.0-static", "3.4.0")
  end

  def test_tags_generate_ruby_abi_tag
    assert_equal "cr34", Gem::Platform::Specific.generate_ruby_abi_tag("ruby", "3.4.1", "3.4.1", "3.4.0")
    assert_equal "cr34_static", Gem::Platform::Specific.generate_ruby_abi_tag("ruby", "3.4.1", "3.4.1", "3.4.0-static")
    assert_equal "cr34____", Gem::Platform::Specific.generate_ruby_abi_tag("ruby", "3.4.1", "3.4.1", "3.4.0-...")
    assert_equal "jr94", Gem::Platform::Specific.generate_ruby_abi_tag("jruby", "9.4.9.0", "3.1.4", "3.1.0")
    assert_equal "tr240", Gem::Platform::Specific.generate_ruby_abi_tag("truffleruby", "24.0.2", "3.2.2", "3.2.2.24.0.0.2")
  end

  def test_self_local_linux_libc_detection
    # Test that Platform.local.to_a remains clean (no version modification)
    util_set_arch "x86_64-linux-gnu" do
      assert_equal ["x86_64", "linux", "gnu"], Gem::Platform.local.to_a
    end

    # Test that Specific.local properly detects glibc on standard Linux systems
    util_set_arch "x86_64-linux-gnu" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 17] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_equal [2, 17], specific.libc_version
        assert_equal ["x86_64", "linux", "gnu"], specific.platform.to_a
      end
    end

    # Test glibc detection with ARM EABI variants
    util_set_arch "arm-linux-gnueabi" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 31] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_equal [2, 31], specific.libc_version
        assert_equal ["arm", "linux", "gnueabi"], specific.platform.to_a
      end
    end

    util_set_arch "arm-linux-gnueabihf" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 28] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_equal [2, 28], specific.libc_version
        assert_equal ["arm", "linux", "gnueabihf"], specific.platform.to_a
      end
    end

    # Test musl detection on musl-based systems
    util_set_arch "x86_64-linux-musl" do
      Gem::Platform::Musllinux.stub :musl_version, [1, 2] do
        specific = Gem::Platform::Specific.local
        assert_equal "musl", specific.libc_type
        assert_equal [1, 2], specific.libc_version
        assert_equal ["x86_64", "linux", "musl"], specific.platform.to_a
      end
    end

    # Test musl detection with ARM EABI variants
    util_set_arch "arm-linux-musleabi" do
      Gem::Platform::Musllinux.stub :musl_version, [1, 1] do
        specific = Gem::Platform::Specific.local
        assert_equal "musl", specific.libc_type
        assert_equal [1, 1], specific.libc_version
        assert_equal ["arm", "linux", "musleabi"], specific.platform.to_a
      end
    end

    util_set_arch "arm-linux-musleabihf" do
      Gem::Platform::Musllinux.stub :musl_version, [1, 3] do
        specific = Gem::Platform::Specific.local
        assert_equal "musl", specific.libc_type
        assert_equal [1, 3], specific.libc_version
        assert_equal ["arm", "linux", "musleabihf"], specific.platform.to_a
      end
    end

    # Test detection failure scenarios - should have nil libc_version when detection fails
    util_set_arch "x86_64-linux-gnu" do
      Gem::Platform::Manylinux.stub :glibc_version, nil do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_nil specific.libc_version
        assert_equal ["x86_64", "linux", "gnu"], specific.platform.to_a
      end
    end

    util_set_arch "x86_64-linux-musl" do
      Gem::Platform::Musllinux.stub :musl_version, nil do
        specific = Gem::Platform::Specific.local
        assert_equal "musl", specific.libc_type
        assert_nil specific.libc_version
        assert_equal ["x86_64", "linux", "musl"], specific.platform.to_a
      end
    end

    # Test that non-glibc/musl Linux systems have glibc detection (default case)
    util_set_arch "arm-linux-uclibceabi" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 24] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type  # defaults to glibc for non-musl Linux
        assert_equal [2, 24], specific.libc_version
        assert_equal ["arm", "linux", "uclibceabi"], specific.platform.to_a
      end
    end

    util_set_arch "arm-linux-uclibceabihf" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 19] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type  # defaults to glibc for non-musl Linux
        assert_equal [2, 19], specific.libc_version
        assert_equal ["arm", "linux", "uclibceabihf"], specific.platform.to_a
      end
    end

    # Test generic Linux systems without libc suffix (defaults to glibc)
    util_set_arch "x86_64-linux" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 35] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_equal [2, 35], specific.libc_version
        assert_equal ["x86_64", "linux", nil], specific.platform.to_a
      end
    end

    # Test basic EABI systems (defaults to glibc)
    util_set_arch "arm-linux-eabi" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 24] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_equal [2, 24], specific.libc_version
        assert_equal ["arm", "linux", "eabi"], specific.platform.to_a
      end
    end

    util_set_arch "arm-linux-eabihf" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 27] do
        specific = Gem::Platform::Specific.local
        assert_equal "glibc", specific.libc_type
        assert_equal [2, 27], specific.libc_version
        assert_equal ["arm", "linux", "eabihf"], specific.platform.to_a
      end
    end

    # Test non-Linux platforms have no libc detection
    util_set_arch "x86_64-darwin20" do
      specific = Gem::Platform::Specific.local
      assert_nil specific.libc_type
      assert_nil specific.libc_version
      assert_equal ["x86_64", "darwin", "20"], specific.platform.to_a
    end

    util_set_arch "x64-mingw-ucrt" do
      specific = Gem::Platform::Specific.local
      assert_nil specific.libc_type
      assert_nil specific.libc_version
      assert_equal ["x64", "mingw", "ucrt"], specific.platform.to_a
    end
  end

  # Tests for parsing Specific string representations

  def test_parse_full_specific_string
    str = "x86_64-linux v:1 engine:ruby engine_version:3.3.1 ruby_version:3.3.1 abi_version:3.3.0 libc_type:glibc libc_version:2.31"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal Gem::Platform.new("x86_64-linux"), specific.platform
    assert_equal "ruby", specific.ruby_engine
    assert_equal "3.3.1", specific.ruby_engine_version
    assert_equal "3.3.1", specific.ruby_version
    assert_equal "3.3.0", specific.abi_version
    assert_equal "glibc", specific.libc_type
    assert_equal [2, 31], specific.libc_version
  end

  def test_parse_minimal_specific_string
    str = "x86_64-linux v:1"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal Gem::Platform.new("x86_64-linux"), specific.platform
    assert_nil specific.ruby_engine
    assert_nil specific.ruby_engine_version
    assert_nil specific.ruby_version
    assert_nil specific.abi_version
    assert_nil specific.libc_type
    assert_nil specific.libc_version
  end

  def test_parse_partial_specific_string
    str = "arm64-darwin v:1 engine:ruby ruby_version:3.2.0 abi_version:3.2.0"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal Gem::Platform.new("arm64-darwin"), specific.platform
    assert_equal "ruby", specific.ruby_engine
    assert_nil specific.ruby_engine_version
    assert_equal "3.2.0", specific.ruby_version
    assert_equal "3.2.0", specific.abi_version
    assert_nil specific.libc_type
    assert_nil specific.libc_version
  end

  def test_parse_with_jruby
    str = "java v:1 engine:jruby engine_version:9.4.0 ruby_version:3.1.0 abi_version:3.1.0"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal Gem::Platform.new("java"), specific.platform
    assert_equal "jruby", specific.ruby_engine
    assert_equal "9.4.0", specific.ruby_engine_version
    assert_equal "3.1.0", specific.ruby_version
    assert_equal "3.1.0", specific.abi_version
  end

  def test_parse_with_musl
    str = "x86_64-linux-musl v:1 libc_type:musl libc_version:1.2"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal Gem::Platform.new("x86_64-linux-musl"), specific.platform
    assert_equal "musl", specific.libc_type
    assert_equal [1, 2], specific.libc_version
  end

  def test_parse_roundtrip_consistency
    # Test that parse(to_s) produces equivalent objects
    original = Gem::Platform::Specific.new(
      "x86_64-linux",
      ruby_engine: "ruby",
      ruby_engine_version: "3.3.1",
      ruby_version: "3.3.1",
      abi_version: "3.3.0",
      libc_type: "glibc",
      libc_version: [2, 31]
    )

    str = original.to_s
    parsed = Gem::Platform::Specific.parse(str)

    assert_equal original, parsed
    assert_equal original.platform, parsed.platform
    assert_equal original.ruby_engine, parsed.ruby_engine
    assert_equal original.ruby_engine_version, parsed.ruby_engine_version
    assert_equal original.ruby_version, parsed.ruby_version
    assert_equal original.abi_version, parsed.abi_version
    assert_equal original.libc_type, parsed.libc_type
    assert_equal original.libc_version, parsed.libc_version
  end

  def test_parse_handles_empty_and_nil
    assert_nil Gem::Platform::Specific.parse(nil)
    assert_nil Gem::Platform::Specific.parse("")
    assert_nil Gem::Platform::Specific.parse("   ")
  end

  def test_parse_handles_various_formats
    # Empty key:value pair should be handled gracefully
    result = Gem::Platform::Specific.parse("x86_64-linux v:1 invalid:")
    assert_equal Gem::Platform.new("x86_64-linux"), result.platform

    # Invalid platform strings create "unknown" platforms but don't error
    result = Gem::Platform::Specific.parse("invalid:platform:format v:1 engine:ruby")
    assert_equal "ruby", result.ruby_engine
    assert_equal "unknown", result.platform.os
  end

  def test_parse_ignores_unknown_attributes
    str = "x86_64-linux v:1 engine:ruby unknown_attr:value another:attr"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal Gem::Platform.new("x86_64-linux"), specific.platform
    assert_equal "ruby", specific.ruby_engine
    # Unknown attributes should be ignored
    assert_nil specific.ruby_version
  end

  def test_parse_handles_single_libc_version
    # Single numeric value should be set to nil (manylinux needs major.minor)
    str = "x86_64-linux v:1 libc_type:glibc libc_version:2"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal "glibc", specific.libc_type
    assert_nil specific.libc_version # Single values are not valid for libc_version
  end

  def test_parse_handles_malformed_libc_version
    # Non-dot format should be set to nil
    str = "x86_64-linux v:1 libc_type:glibc libc_version:invalid"
    specific = Gem::Platform::Specific.parse(str)

    assert_equal "glibc", specific.libc_type
    assert_nil specific.libc_version # Malformed libc_version becomes nil
  end

  def test_to_s_uses_dot_format_and_includes_version
    # Test that to_s now uses the dot format and includes version
    specific = Gem::Platform::Specific.new(
      "x86_64-linux",
      libc_type: "glibc",
      libc_version: [2, 31]
    )

    str = specific.to_s
    assert_includes str, "v:1"
    assert_includes str, "libc_version:2.31"
    refute_includes str, "[2, 31]"
  end

  def test_parse_requires_version
    # Missing version should raise error
    error = assert_raise(ArgumentError) do
      Gem::Platform::Specific.parse("x86_64-linux engine:ruby")
    end
    assert_match(/missing required version field/, error.message)
  end

  def test_parse_rejects_unsupported_version
    # Unsupported version should raise error
    error = assert_raise(ArgumentError) do
      Gem::Platform::Specific.parse("x86_64-linux v:2 engine:ruby")
    end
    assert_match(/unsupported specific format version: 2/, error.message)

    error = assert_raise(ArgumentError) do
      Gem::Platform::Specific.parse("x86_64-linux v:0 engine:ruby")
    end
    assert_match(/unsupported specific format version: 0/, error.message)
  end

  def test_specific_linux_libc_tag_generation
    # Test that Linux Specific platforms generate appropriate manylinux/musllinux tags

    # Test glibc platform generates manylinux tags
    util_set_arch "x86_64-linux-gnu" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 17] do
        specific = Gem::Platform::Specific.local
        platform_tags = specific.each_possible_match.to_a

        # Should include manylinux tags
        manylinux_tags = platform_tags.select {|_, tag| tag.start_with?("manylinux") }
        refute_empty manylinux_tags, "glibc platform should generate manylinux tags"

        # Should include at least manylinux_2_17_x86_64
        assert platform_tags.any? {|_, tag| tag == "manylinux_2_17_x86_64" },
          "Should include manylinux_2_17_x86_64 tag for glibc 2.17"
      end
    end

    # Test musl platform generates musllinux tags
    util_set_arch "x86_64-linux-musl" do
      Gem::Platform::Musllinux.stub :musl_version, [1, 2] do
        specific = Gem::Platform::Specific.local
        platform_tags = specific.each_possible_match.to_a

        # Should include musllinux tags
        musllinux_tags = platform_tags.select {|_, tag| tag.start_with?("musllinux") }
        refute_empty musllinux_tags, "musl platform should generate musllinux tags"

        # Should include at least musllinux_1_2_x86_64
        assert platform_tags.any? {|_, tag| tag == "musllinux_1_2_x86_64" },
          "Should include musllinux_1_2_x86_64 tag for musl 1.2"
      end
    end

    # Test ARM glibc platform generates appropriate manylinux tags
    util_set_arch "arm-linux-gnueabihf" do
      Gem::Platform::Manylinux.stub :glibc_version, [2, 28] do
        specific = Gem::Platform::Specific.local
        platform_tags = specific.each_possible_match.to_a

        # Should include manylinux tags for ARM
        manylinux_tags = platform_tags.select {|_, tag| tag.start_with?("manylinux") && tag.include?("arm") }
        refute_empty manylinux_tags, "ARM glibc platform should generate arm manylinux tags"

        # Should include at least manylinux_2_28_arm
        assert platform_tags.any? {|_, tag| tag == "manylinux_2_28_arm" },
          "Should include manylinux_2_28_arm tag for ARM glibc 2.28"
      end
    end

    # Test that platforms without libc versions don't generate specific tags
    util_set_arch "x86_64-linux-gnu" do
      Gem::Platform::Manylinux.stub :glibc_version, nil do
        specific = Gem::Platform::Specific.local
        platform_tags = specific.each_possible_match.to_a

        # Should still include generic linux tags but no versioned manylinux tags
        assert platform_tags.any? {|_, tag| tag == "x86_64_linux" },
          "Should include generic x86_64_linux tag"

        # Should not include versioned manylinux tags when libc version is nil
        versioned_manylinux_tags = platform_tags.select {|_, tag| tag.match?(/manylinux_\d+_\d+/) }
        assert_empty versioned_manylinux_tags, "Should not generate versioned manylinux tags without libc version"
      end
    end
  end
end
