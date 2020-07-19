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

namespace :release do
  task :verify_docs => :"man:check"

  desc "Push the release to Github releases"
  task :github do
    version = Gem::Version.new(Bundler::GemHelper.gemspec.version)
    release_notes = Changelog.bundler.release_notes(version)
    tag = "bundler-v#{version}"

    GithubInfo.client.create_release "rubygems/rubygems", tag, :name => tag,
                                                               :body => release_notes,
                                                               :prerelease => version.prerelease?
  end

  desc "Prepare a patch release with the PRs from master in the patch milestone"
  task :prepare_patch, :version do |_t, args|
    version = args.version

    version ||= begin
      current_version = Gem::Version.new(GithubInfo.latest_release.tag_name.gsub(/^bundler-v/, ""))
      segments = current_version.segments
      if segments.last.is_a?(String)
        segments << "1"
      else
        segments[-1] += 1
      end
      segments.join(".")
    end

    puts "Cherry-picking PRs with patch-level compatible tags into the stable branch..."

    gh_client = GithubInfo.client
    changelog = Changelog.bundler_patch_level

    branch = Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join(".")

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

      changelog.cut!(version.to_s)

      sh("git", "commit", "-am", "Version #{version} with changelog")
    rescue StandardError
      sh("git", "checkout", previous_branch)
      sh("git", "branch", "-D", release_branch)
      raise
    end
  end
end
