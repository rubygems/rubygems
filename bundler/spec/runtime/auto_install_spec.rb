# frozen_string_literal: true

RSpec.describe "Bundler.auto_install" do
  describe "with a gemfile" do
    before do
      gemfile <<-G
        source "#{file_uri_for(gem_repo1)}"
        gem "rack", :group => :test
      G
    end

    it "installs the gems" do
      # NOTE: only require bundler to make the method calls. spec/runtime/setup_spec.rb covers requiring bundler/setup
      ruby <<-RUBY
        require 'bundler'
        Bundler.auto_install
        Bundler.setup
      RUBY

      expect(err).to be_empty
      expect(out).to include("Installing rack 1.0.0")
    end
  end
end

