# frozen_string_literal: true

require_relative "changelog"

class Release
  def self.for_bundler(version)
    new(
      version,
      changelog: Changelog.for_bundler(version),
      release_branch: "release_bundler/#{version}",
      stable_branch: Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join("."),
      version_file: File.expand_path("../bundler/lib/bundler/version.rb", __dir__),
      title: "Bundler version #{version} with changelog",
    )
  end

  def self.for_rubygems(version)
    new(
      version,
      changelog: Changelog.for_rubygems(version),
      release_branch: "release_rubygems/#{version}",
      stable_branch: Gem::Version.new(version).segments[0, 2].join("."),
      version_file: File.expand_path("../lib/rubygems.rb", __dir__),
      title: "Rubygems version #{version} with changelog",
    )
  end

  def initialize(version, changelog:, stable_branch:, release_branch:, version_file:, title:)
    @version = version
    @changelog = changelog
    @stable_branch = stable_branch
    @release_branch = release_branch
    @version_file = version_file
    @title = title
  end

  def prepare!
    initial_branch = `git rev-parse --abbrev-ref HEAD`.strip

    system("git", "checkout", "-b", @release_branch, @stable_branch, exception: true)

    begin
      prs = @changelog.relevant_pull_requests_since_last_release

      if prs.any? && !system("git", "cherry-pick", "-x", "-m", "1", *prs.map(&:merge_commit_sha))
        warn <<~MSG
          Opening a new shell to fix the cherry-pick errors manually. Run `git add . && git cherry-pick --continue` once done, and if it succeeds, run `exit 0` to resume the task.

          Otherwise type `Ctrl-D` to cancel
        MSG

        unless system(ENV["SHELL"] || "zsh")
          system("git", "cherry-pick", "--abort", exception: true)
          raise "Failed to resolve conflitcs, resetting original state"
        end
      end

      version_contents = File.read(@version_file)
      unless version_contents.sub!(/^(\s*VERSION = )"#{Gem::Version::VERSION_PATTERN}"/, "\\1#{@version.to_s.dump}")
        raise "Failed to update #{@version_file}, is it in the expected format?"
      end
      File.open(@version_file, "w") {|f| f.write(version_contents) }

      @changelog.cut!

      system("git", "commit", "-am", @title, exception: true)
    rescue StandardError
      system("git", "checkout", initial_branch, exception: true)
      system("git", "branch", "-D", @release_branch, exception: true)
      raise
    end
  end
end
