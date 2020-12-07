# frozen_string_literal: true

require_relative "changelog"

class Release
  def self.for_bundler(version)
    new(
      version,
      changelog: Changelog.for_bundler(version),
      release_branch: "release_bundler/#{version}",
      stable_branch: Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join("."),
      version_files: [File.expand_path("../bundler/lib/bundler/version.rb", __dir__)],
      title: "Bundler version #{version} with changelog",
      tag_prefix: "bundler-v",
    )
  end

  def self.for_rubygems(version)
    new(
      version,
      changelog: Changelog.for_rubygems(version),
      release_branch: "release_rubygems/#{version}",
      stable_branch: Gem::Version.new(version).segments[0, 2].join("."),
      version_files: [File.expand_path("../lib/rubygems.rb", __dir__), File.expand_path("../rubygems-update.gemspec", __dir__)],
      title: "Rubygems version #{version} with changelog",
      tag_prefix: "v",
    )
  end

  def initialize(version, changelog:, stable_branch:, release_branch:, version_files:, title:, tag_prefix:)
    @version = version
    @changelog = changelog
    @stable_branch = stable_branch
    @release_branch = release_branch
    @version_files = version_files
    @title = title
    @tag_prefix = tag_prefix
  end

  def prepare!
    initial_branch = `git rev-parse --abbrev-ref HEAD`.strip

    system("git", "checkout", "-b", @release_branch, @stable_branch, exception: true)

    begin
      prs = relevant_unreleased_pull_requests

      if prs.any? && !system("git", "cherry-pick", "-x", "-m", "1", *prs.map(&:merge_commit_sha))
        warn <<~MSG

          Opening a new shell to fix the cherry-pick errors manually. You can do the following now:

          * Find the PR that caused the merge conflict.
          * If you'd like to include that PR in the release, tag it with an appropriate label. Then type `Ctrl-D` and rerun the task so that the PR is cherry-picked before and the conflict is fixed.
          * If you don't want to include that PR in the release, fix conflicts manually, run `git add . && git cherry-pick --continue` once done, and if it succeeds, run `exit 0` to resume the release preparation.

        MSG

        unless system(ENV["SHELL"] || "zsh")
          system("git", "cherry-pick", "--abort", exception: true)
          raise "Failed to resolve conflicts, resetting original state"
        end
      end

      @version_files.each do |version_file|
        version_contents = File.read(version_file)
        unless version_contents.sub!(/^(.*VERSION = )"#{Gem::Version::VERSION_PATTERN}"/i, "\\1#{@version.to_s.dump}")
          raise "Failed to update #{version_file}, is it in the expected format?"
        end
        File.open(version_file, "w") {|f| f.write(version_contents) }
      end

      @changelog.cut!(previous_version, prs)

      system("git", "commit", "-am", @title, exception: true)
    rescue StandardError
      system("git", "checkout", initial_branch, exception: true)
      system("git", "branch", "-D", @release_branch, exception: true)
      raise
    end
  end

  def cut_changelog!
    @changelog.cut!(previous_version, relevant_pull_requests_since_last_release)
  end

  def create_for_github!
    tag = "#{@tag_prefix}#{@version}"

    gh_client.create_release "rubygems/rubygems", tag, :name => tag,
                                                       :body => @changelog.release_notes.join("\n").strip,
                                                       :prerelease => @version.prerelease?
  end

  private

  def relevant_unreleased_pull_requests
    pr_ids = unreleased_pr_ids

    relevant_pull_requests_for(pr_ids)
  end

  def previous_version
    latest_release.tag_name.gsub(/^#{@tag_prefix}/, "")
  end

  def latest_release
    @latest_release ||= gh_client.releases("rubygems/rubygems").select {|release| release.tag_name.start_with?(@tag_prefix) }.sort_by(&:created_at).last
  end

  def relevant_pull_requests_for(ids)
    pulls = gh_client.pull_requests("rubygems/rubygems", :sort => :updated, :state => :closed, :direction => :desc)

    loop do
      pulls.select! {|pull| ids.include?(pull.number) }

      break if (pulls.map(&:number) & ids).to_set == ids.to_set

      pulls.concat gh_client.get(gh_client.last_response.rels[:next].href)
    end

    pulls.select {|pull| @changelog.relevant_label_for(pull) }.sort_by(&:merged_at)
  end

  def unreleased_pr_ids
    stable_merge_commit_messages = `git log --format=%s --grep "^Merge pull request #" #{@stable_branch}`.split("\n")

    `git log --oneline --grep "^Merge pull request #" origin/master`.split("\n").map do |l|
      _sha, message = l.split(/\s/, 2)

      next if stable_merge_commit_messages.include?(message)

      /^Merge pull request #(\d+)/.match(message)[1].to_i
    end.compact
  end

  def gh_client
    @gh_client ||= begin
      require "netrc"
      _username, token = Netrc.read["api.github.com"]

      require "octokit"
      Octokit::Client.new(:access_token => token)
    end
  end
end
