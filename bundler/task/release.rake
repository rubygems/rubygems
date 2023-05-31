# frozen_string_literal: true

require_relative "../lib/bundler/gem_tasks"
require_relative "../spec/support/build_metadata"
require_relative "../../tool/release"

Bundler::GemHelper.tag_prefix = "bundler-"

task :build_metadata do
  Spec::BuildMetadata.write_build_metadata
end

namespace :build_metadata do
  task :clean do
    Spec::BuildMetadata.reset_build_metadata
  end
end

task :build => ["build_metadata"] do
  Rake::Task["build_metadata:clean"].tap(&:reenable).invoke
end
task "release:rubygem_push" => ["release:setup", "man:check", "build_metadata", "release:github"]

desc "Generates the changelog for a specific target version"
task :generate_changelog, [:version] do |_t, opts|
  Release.for_bundler(opts[:version]).cut_changelog!
end

namespace :release do
  desc "Install gems needed for releasing"
  task :setup do
    Release.install_dependencies!
  end

  desc "Push the release to GitHub releases"
  task :github do
    gemspec_version = Bundler::GemHelper.gemspec.version

    Release.for_bundler(gemspec_version).create_for_github!
  end
end
