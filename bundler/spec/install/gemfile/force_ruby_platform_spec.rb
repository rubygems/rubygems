# frozen_string_literal: true

RSpec.describe "bundle install with force_ruby_platform DSL option" do
  before do
    bundle "config set specific_platform true"
  end

  it "pulls the pure ruby variant under all platforms" do
    build_repo4 do
      # Build a gem with platform specific versions
      build_gem("platform_specific") do |s|
        s.write "lib/platform_specific.rb", "PLATFORM_SPECIFIC = '1.0.0 RUBY'"
      end

      build_gem("platform_specific") do |s|
        s.platform = "java"
        s.write "lib/platform_specific.rb", "PLATFORM_SPECIFIC = '1.0.0 JAVA'"
      end

      build_gem("platform_specific") do |s|
        s.platform = "x64-mingw32"
        s.write "lib/platform_specific.rb", "PLATFORM_SPECIFIC = '1.0.0 x64-mingw32'"
      end

      # Build the exact same gem with a different name to compare using vs not using the option
      build_gem("platform_specific_forced") do |s|
        s.write "lib/platform_specific_forced.rb", "PLATFORM_SPECIFIC_FORCED = '1.0.0 RUBY'"
      end

      build_gem("platform_specific_forced") do |s|
        s.platform = "java"
        s.write "lib/platform_specific_forced.rb", "PLATFORM_SPECIFIC_FORCED = '1.0.0 JAVA'"
      end

      build_gem("platform_specific_forced") do |s|
        s.platform = "x64-mingw32"
        s.write "lib/platform_specific_forced.rb", "PLATFORM_SPECIFIC_FORCED = '1.0.0 x64-mingw32'"
      end
    end

    simulate_platform "ruby" do
      install_gemfile <<-G
        source "#{file_uri_for(gem_repo4)}"

        gem "platform_specific_forced", :force_ruby_platform => true
        gem "platform_specific"
      G

      expect(the_bundle).to include_gems "platform_specific_forced 1.0 RUBY"
      expect(the_bundle).to include_gems "platform_specific 1.0 RUBY"
    end

    simulate_platform "java" do
      install_gemfile <<-G
        source "#{file_uri_for(gem_repo4)}"

        gem "platform_specific_forced", :force_ruby_platform => true
        gem "platform_specific"
      G

      expect(the_bundle).to include_gems "platform_specific_forced 1.0 RUBY"
      expect(the_bundle).to include_gems "platform_specific 1.0 JAVA"
    end

    simulate_windows x64_mingw do
      install_gemfile <<-G
        source "#{file_uri_for(gem_repo4)}"

        gem "platform_specific_forced", :force_ruby_platform => true
        gem "platform_specific"
      G

      expect(the_bundle).to include_gems "platform_specific_forced 1.0 RUBY"
      expect(the_bundle).to include_gems "platform_specific 1.0 x64-mingw32"
    end
  end

  context "when also a transitive dependency" do
    before do
      build_repo4 do
        build_gem("depends_on_platform_specific") {|s| s.add_runtime_dependency "platform_specific" }

        build_gem("platform_specific") do |s|
          s.write "lib/platform_specific.rb", "PLATFORM_SPECIFIC = '1.0.0 RUBY'"
        end

        build_gem("platform_specific") do |s|
          s.platform = "java"
          s.write "lib/platform_specific.rb", "PLATFORM_SPECIFIC = '1.0.0 JAVA'"
        end

        build_gem("platform_specific") do |s|
          s.platform = "x64-mingw32"
          s.write "lib/platform_specific.rb", "PLATFORM_SPECIFIC = '1.0.0 x64-mingw32'"
        end
      end
    end

    it "still pulls the ruby variant" do
      simulate_platform "ruby" do
        install_gemfile <<-G
          source "#{file_uri_for(gem_repo4)}"

          gem "depends_on_platform_specific"
          gem "platform_specific", :force_ruby_platform => true
        G

        expect(the_bundle).to include_gems "platform_specific 1.0.0 RUBY"
      end

      simulate_platform "java" do
        install_gemfile <<-G
          source "#{file_uri_for(gem_repo4)}"

          gem "depends_on_platform_specific"
          gem "platform_specific", :force_ruby_platform => true
        G

        expect(the_bundle).to include_gems "platform_specific 1.0.0 RUBY"
      end

      simulate_windows x64_mingw do
        install_gemfile <<-G
          source "#{file_uri_for(gem_repo4)}"

          gem "depends_on_platform_specific"
          gem "platform_specific", :force_ruby_platform => true
        G

        expect(the_bundle).to include_gems "platform_specific 1.0.0 RUBY"
      end
    end
  end
end
