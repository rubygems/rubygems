# frozen_string_literal: true

require_relative "../lib/bundler/gem_tasks"
require_relative "../spec/support/build_metadata"
require_relative "../../util/changelog"

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
    version = opts[:version]
    changelog = Changelog.for_bundler(version)

    branch = version.segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join(".")

    previous_branch = `git rev-parse --abbrev-ref HEAD`.strip
    release_branch = "release_bundler/#{version}"

    sh("git", "checkout", "-b", release_branch, branch)

    begin
      prs = changelog.relevant_pull_requests_since_last_release

      if prs.any? && !system("git", "cherry-pick", "-x", "-m", "1", *prs.map(&:merge_commit_sha))
        warn <<~MSG
          Opening a new shell to fix the cherry-pick errors manually. Run `git add . && git cherry-pick --continue` once done, and if it succeeds, run `exit 0` to resume the task.

          Otherwise type `Ctrl-D` to cancel
        MSG

        unless system(ENV["SHELL"] || "zsh")
          raise "Failed to resolve conflitcs, resetting original state"
        end
      end

      version_file = "lib/bundler/version.rb"
      version_contents = File.read(version_file)
      unless version_contents.sub!(/^(\s*VERSION = )"#{Gem::Version::VERSION_PATTERN}"/, "\\1#{version.to_s.dump}")
        raise "Failed to update #{version_file}, is it in the expected format?"
      end
      File.open(version_file, "w") {|f| f.write(version_contents) }

      changelog.cut!

      sh("git", "commit", "-am", "Version #{version} with changelog")
    rescue StandardError
      sh("git", "checkout", previous_branch)
      sh("git", "branch", "-D", release_branch)
      raise
    end
  end
end
