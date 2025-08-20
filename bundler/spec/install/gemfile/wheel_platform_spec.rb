# frozen_string_literal: true

RSpec.describe "bundle install with wheel platform gems" do
  before do
    build_repo4 do
      # Build wheel platform specific gems
      build_gem "wheel_native", "1.0.0" do |s|
        s.platform = "whl-rb33-x86_64_linux"
        s.write "lib/wheel_native.rb", "WHEEL_NATIVE = '1.0.0 whl-rb33-x86_64_linux'"
      end

      build_gem "wheel_native", "1.0.0" do |s|
        s.platform = "whl-rb32-x86_64_linux"
        s.write "lib/wheel_native.rb", "WHEEL_NATIVE = '1.0.0 whl-rb32-x86_64_linux'"
      end

      build_gem "wheel_native", "1.0.0" do |s|
        s.platform = "whl-rb33-x86_64_darwin"
        s.write "lib/wheel_native.rb", "WHEEL_NATIVE = '1.0.0 whl-rb33-x86_64_darwin'"
      end

      # Fallback ruby gem
      build_gem "wheel_native", "1.0.0" do |s|
        s.platform = "ruby"
        s.write "lib/wheel_native.rb", "WHEEL_NATIVE = '1.0.0 ruby'"
      end

      # Multi-tag wheel gem
      build_gem "multi_wheel", "2.0.0" do |s|
        s.platform = "whl-rb33.rb32-x86_64_linux"
        s.write "lib/multi_wheel.rb", "MULTI_WHEEL_VERSION = '2.0.0-whl-rb33.rb32-x86_64_linux'"
      end

      build_gem "multi_wheel", "2.0.0" do |s|
        s.platform = "ruby"
        s.write "lib/multi_wheel.rb", "MULTI_WHEEL_VERSION = '2.0.0-ruby'"
      end
    end
  end

  context "when wheel platform gem is available for current platform" do
    it "installs the wheel platform specific gem" do
      skip "Wheel platform detection not fully implemented in resolver yet"

      install_gemfile <<-G
        source "https://gem.repo4"
        gem "wheel_native"
      G

      expect(the_bundle).to include_gems "wheel_native 1.0.0"
      # Would need to check that the correct platform version was installed
    end
  end

  context "when no wheel platform gem matches" do
    it "falls back to ruby platform gem" do
      install_gemfile <<-G
        source "https://gem.repo4"
        gem "wheel_native"
      G

      expect(the_bundle).to include_gems "wheel_native 1.0.0"

      ruby <<-R
        require 'wheel_native'
        puts WHEEL_NATIVE
      R

      expect(out).to include("1.0.0 ruby")
    end
  end

  context "with multi-tag wheel gems" do
    it "matches compatible multi-tag wheel gems" do
      skip "Multi-tag wheel matching not fully implemented yet"

      install_gemfile <<-G
        source "https://gem.repo4"
        gem "multi_wheel"
      G

      expect(the_bundle).to include_gems "multi_wheel 2.0.0"
    end
  end

  context "platform resolution priority" do
    it "prefers wheel platform over traditional platform" do
      skip "Platform priority not fully implemented in bundler yet"

      build_repo4 do
        # Traditional platform gem
        build_gem "priority_test", "1.0.0" do |s|
          s.platform = "x86_64-linux"
          s.write "lib/priority_test.rb", "PRIORITY_VERSION = '1.0.0-x86_64-linux'"
        end

        # Wheel platform gem (should have higher priority)
        build_gem "priority_test", "1.0.0" do |s|
          s.platform = "whl-rb33-x86_64_linux"
          s.write "lib/priority_test.rb", "PRIORITY_VERSION = '1.0.0-whl-rb33-x86_64_linux'"
        end
      end

      install_gemfile <<-G
        source "https://gem.repo4"
        gem "priority_test"
      G

      ruby <<-R
        require 'priority_test'
        puts PRIORITY_VERSION
      R

      # Should prefer wheel platform over traditional platform
      expect(out).to include("whl-rb33-x86_64_linux")
    end
  end

  context "lockfile generation with wheel platforms" do
    it "records wheel platforms in the lockfile" do
      skip "Lockfile wheel platform recording not implemented yet"

      install_gemfile <<-G
        source "https://gem.repo4"
        gem "wheel_native"
      G

      lockfile_should_be <<-L
        GEM
          remote: https://gem.repo4/
          specs:
            wheel_native (1.0.0-whl-rb33-x86_64_linux)

        PLATFORMS
          whl-rb33-x86_64_linux

        DEPENDENCIES
          wheel_native

        BUNDLED WITH
           #{Bundler::VERSION}
      L
    end
  end
end
