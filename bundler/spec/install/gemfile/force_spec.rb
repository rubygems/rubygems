# frozen_string_literal: true

require "spec_helper"

RSpec.describe "bundle install with a gemfile that forces a gem version" do
  context "with a simple conflict" do
    it "works" do
      install_gemfile <<-G
        source "#{file_uri_for(gem_repo1)}"
        gem "rack_middleware"
        gem "rack", "1.0.0", :force_version => true
      G

      expect(the_bundle).to include_gems("rack 1.0.0", "rack_middleware 1.0")
    end

    it "raises when forcing to an inexact version" do
      gemfile <<-G
        gem "rack", "> 1.0.0", :force_version => true
      G

      bundle :install, :quiet => true, :raise_on_error => false

      expect(exitstatus).to_not eq(0)
      expect(err).to include("Cannot use force_version for inexact version requirement `> 1.0.0`.")
    end

    it "raises when forcing without specifying a version" do
      gemfile <<-G
        gem "rack", :force_version => true
      G

      bundle :install, :quiet => true, :raise_on_error => false

      expect(exitstatus).to_not eq(0)
      expect(err).to include("Cannot use force_version for inexact version requirement `>= 0`.")
    end

    it "works when there's no conflict" do
      install_gemfile <<-G
        source "#{file_uri_for(gem_repo1)}"
        gem "rack", "1.0.0", :force_version => true
      G

      expect(the_bundle).to include_gems("rack 1.0.0")
    end

    it "raises when gem doesn't exist" do
      gemfile <<-G
        source "#{file_uri_for(gem_repo1)}"
        gem "rack_middleware"
        gem "rack", "2.0.0", :force_version => true
      G

      bundle :install, :quiet => true, :raise_on_error => false

      expect(exitstatus).to_not eq(0)
      expect(err).to include("Could not find gem 'rack (= 2.0.0)")
    end
  end

  context "with a complex conflict" do
    it "works" do
      install_gemfile <<-G
        source "#{file_uri_for(gem_repo1)}"
        gem "rails", "2.3.2"
        gem "activesupport", "2.3.5", :force_version => true
      G

      expect(the_bundle).to include_gems("rails 2.3.2", "activesupport 2.3.5", "actionpack 2.3.2", "activerecord 2.3.2", "actionmailer 2.3.2", "activeresource 2.3.2")
    end

    it "resolves even with clashing requirements" do
      build_repo4 do
        build_gem "first_parent", %w[1.0.0] do |s|
          s.add_dependency "wasabi", "~> 3.6"
        end
        build_gem "second_parent", %w[1.0.0] do |s|
          s.add_dependency "wasabi", "~> 3.1.0"
        end
        build_gem "wasabi", %w[3.1.0 3.6.1]
      end

      install_gemfile <<-G
        source "#{file_uri_for(gem_repo4)}"
        gem "first_parent"
        gem "second_parent"
        gem "wasabi", "3.6.1", :force_version => true
      G

      expect(the_bundle).to include_gems("first_parent 1.0.0", "second_parent 1.0.0", "wasabi 3.6.1")
    end

    it "resolves even with complex multi-source" do
      build_repo2 do
        build_gem "sfmc-fuelsdk-ruby", %w[1.3.2] do |s|
          s.add_dependency "wasabi", "3.6.1"
          s.add_dependency "jwt", "~> 2.2"
        end
        build_gem "cognito-rack", %w[0.16.6] do |s|
          s.add_dependency "jwt", "~> 2.2"
        end
      end

      build_repo4 do
        build_gem "skynet", %w[2.0.2] do |s|
          s.add_dependency "sfmc-fuelsdk-ruby", "1.3.2"
        end
        build_gem "sfmc-fuelsdk-ruby", %w[1.3.0] do |s|
          s.add_dependency "wasabi", "3.1.0"
          s.add_dependency "jwt", [">= 1.0.0", "~> 1.0"]
        end
        build_gem "wasabi", %w[3.1.0 3.6.1]
        build_gem "jwt", %w[1.0.0 2.2]
      end

      install_gemfile <<-G
        source "#{file_uri_for(gem_repo4)}"
        gem "skynet"
        source "#{file_uri_for(gem_repo2)}" do
          gem "sfmc-fuelsdk-ruby"
          gem "cognito-rack"
        end
      G

      gemfile <<-G
        source "#{file_uri_for(gem_repo4)}"
        gem "sfmc-fuelsdk-ruby", "1.3.0", :force_version => true
        gem "jwt", "2.2", :force_version => true
        gem "skynet"
        source "#{file_uri_for(gem_repo2)}" do
          gem "cognito-rack"
        end
      G

      bundle "update sfmc-fuelsdk-ruby"

      expect(the_bundle).to include_gems("skynet 2.0.2", "sfmc-fuelsdk-ruby 1.3.0", "wasabi 3.1.0")
    end
  end

  context "shows indicator that force_version was active" do
    it "works" do
      gemfile <<-G
        source "#{file_uri_for(gem_repo1)}"
        gem "rack_middleware"
        gem "rack", "1.0.0", :force_version => true
      G

      bundle :install

      expect(out).to include("Installing rack 1.0.0 [version forced]")

      if Gem::Version.create(Bundler::VERSION).segments.first < 3
        bundle :install

        expect(out).to include("Using rack 1.0.0 [version forced]")
      end
    end
  end
end
