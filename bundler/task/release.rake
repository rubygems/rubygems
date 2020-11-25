# frozen_string_literal: true

require_relative "../lib/bundler/gem_tasks"
require_relative "../spec/support/build_metadata"
require_relative "../../util/changelog"
require_relative "../../util/release"

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
task "release:rubygem_push" => ["release:verify_docs", "build_metadata", "release:github"]

desc "Generates the changelog for a specific target version"
task :generate_changelog, [:version] do |_t, opts|
  Changelog.for_bundler(opts[:version]).cut!
end

namespace :release do
  task :verify_docs => :"man:check"

  desc "Push the release to Github releases"
  task :github do
    gemspec_version = Bundler::GemHelper.gemspec.version
    version = Gem::Version.new(gemspec_version)
    release_notes = Changelog.for_bundler(gemspec_version).release_notes
    tag = "bundler-v#{version}"

    GithubInfo.client.create_release "rubygems/rubygems", tag, :name => tag,
                                                               :body => release_notes.join("\n").strip,
                                                               :prerelease => version.prerelease?
  end

  desc "Prepare a new release"
  task :prepare, [:version] do |_t, opts|
    Release.for_bundler(opts[:version]).prepare!
  end
end
