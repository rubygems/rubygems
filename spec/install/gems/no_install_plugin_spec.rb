# frozen_string_literal: true

RSpec.describe "bundle install with --no-install-plugin" do
  before do
    build_repo2 do
      build_gem "with_plugin" do |s|
        s.write "lib/rubygems_plugin.rb", "# plugin code"
      end
    end
  end

  it "skips installing plugins when no_install_plugin is set" do
    bundle_config "no_install_plugin true"

    gemfile <<-G
      source "https://gem.repo2"
      gem "with_plugin"
    G

    bundle :install

    plugin_path = default_bundle_path("plugins", "with_plugin_plugin.rb")
    expect(plugin_path).not_to exist
  end

  it "installs plugins by default" do
    gemfile <<-G
      source "https://gem.repo2"
      gem "with_plugin"
    G

    bundle :install

    plugin_path = default_bundle_path("plugins", "with_plugin_plugin.rb")
    expect(plugin_path).to exist
  end
end
