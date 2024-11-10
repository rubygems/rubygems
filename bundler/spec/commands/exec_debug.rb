require_relative "../spec_helper"

system_gems_to_install= %w[myrack-1.0.0 myrack-0.9.1]
system_gems(system_gems_to_install, path: default_bundle_path)

gemfile "CustomGemfile", <<-G
      source "https://gem.repo1"
      gem "myrack", "1.0.0"
G

bundle "exec --gemfile CustomGemfile myrackup"

