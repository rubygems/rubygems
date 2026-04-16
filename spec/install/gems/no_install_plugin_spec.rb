# frozen_string_literal: true

RSpec.describe "bundle install with --no-install-plugin" do
  before do
    build_repo2 do
      build_gem "with_plugin", "1.0" do |s|
        s.write "lib/rubygems_plugin.rb", "# plugin code"
      end

      build_gem "with_plugin", "2.0"
    end
  end

  let(:plugin_path) { default_bundle_path("plugins", "with_plugin_plugin.rb") }

  it "does not generate the plugin wrapper when no_install_plugin is set" do
    bundle_config "no_install_plugin true"

    install_gemfile <<-G
      source "https://gem.repo2"
      gem "with_plugin", "1.0"
    G

    expect(plugin_path).not_to exist
  end

  it "removes a stale plugin wrapper from a prior version when no_install_plugin is set" do
    install_gemfile <<-G
      source "https://gem.repo2"
      gem "with_plugin", "1.0"
    G
    expect(plugin_path).to exist

    bundle_config "no_install_plugin true"
    install_gemfile <<-G
      source "https://gem.repo2"
      gem "with_plugin", "2.0"
    G

    expect(plugin_path).not_to exist
  end

  it "generates the plugin wrapper by default" do
    install_gemfile <<-G
      source "https://gem.repo2"
      gem "with_plugin", "1.0"
    G

    expect(plugin_path).to exist
  end
end
