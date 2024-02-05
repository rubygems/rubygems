# frozen_string_literal: true

require_relative "changelog"

class Release
  module GithubAPI
    def gh_client
      @gh_client ||= begin
        require "octokit"
        Octokit::Client.new(access_token: ENV["GITHUB_RELEASE_PAT"])
      end
    end
  end

  module SubRelease
    include GithubAPI

    attr_reader :version, :changelog, :version_files, :tag_prefix

    def cut_changelog_for!(pull_requests)
      set_relevant_pull_requests_from(pull_requests)

      cut_changelog!
    end

    def cut_changelog!
      @changelog.cut!(previous_version, relevant_pull_requests, extra_entry: extra_entry)
    end

    def bump_versions!
      version_files.each do |version_file|
        version_contents = File.read(version_file)
        unless version_contents.sub!(/^(.*VERSION = )"#{Gem::Version::VERSION_PATTERN}"/i, "\\1#{version.to_s.dump}")
          raise "Failed to update #{version_file}, is it in the expected format?"
        end
        File.open(version_file, "w") {|f| f.write(version_contents) }
      end
    end

    def create_for_github!
      tag = "#{@tag_prefix}#{@version}"

      gh_client.create_release "rubygems/rubygems", tag, name: tag,
                                                         body: @changelog.release_notes.join("\n").strip,
                                                         prerelease: @version.prerelease?,
                                                         target_commitish: @stable_branch
    end

    def previous_version
      @previous_version ||= remove_tag_prefix(latest_release.tag_name)
    end

    def latest_release
      @latest_release ||= gh_client.releases("rubygems/rubygems").select {|release| release.tag_name.start_with?(@tag_prefix) }.max_by do |release|
        Gem::Version.new(remove_tag_prefix(release.tag_name))
      end
    end

    attr_reader :relevant_pull_requests

    def set_relevant_pull_requests_from(pulls)
      @relevant_pull_requests = pulls.select {|pull| @changelog.relevant_label_for(pull) }
    end

    private

    def remove_tag_prefix(name)
      name.gsub(/^#{@tag_prefix}/, "")
    end
  end

  class Bundler
    include SubRelease

    def initialize(version, stable_branch)
      @version = Gem::Version.new(version)
      @stable_branch = stable_branch
      @changelog = Changelog.for_bundler(version)
      @version_files = [File.expand_path("../bundler/lib/bundler/version.rb", __dir__)]
      @tag_prefix = "bundler-v"
    end

    def extra_entry
      nil
    end
  end

  class Rubygems
    include SubRelease

    def initialize(version, stable_branch)
      @version = Gem::Version.new(version)
      @stable_branch = stable_branch
      @changelog = Changelog.for_rubygems(version)
      @version_files = [File.expand_path("../lib/rubygems.rb", __dir__), File.expand_path("../rubygems-update.gemspec", __dir__)]
      @tag_prefix = "v"
    end

    def extra_entry
      "Installs bundler #{bundler_version} as a default gem"
    end

    private

    def bundler_version
      version.segments.map.with_index {|s, i| i == 0 ? s - 1 : s }.join(".")
    end
  end

  include GithubAPI

  def self.install_dependencies!
    system(
      "ruby",
      "-I",
      File.expand_path("../lib", __dir__),
      File.expand_path("../bundler/spec/support/bundle.rb", __dir__),
      "install",
      "--gemfile=#{File.expand_path("bundler/release_gems.rb", __dir__)}",
      exception: true
    )
  end

  def self.for_bundler(version)
    rubygems_version = Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }.join(".")

    release = new(rubygems_version)
    release.set_bundler_as_current_library
    release
  end

  def self.for_rubygems(version)
    release = new(version)
    release.set_rubygems_as_current_library
    release
  end

  #
  # Accepts the version of the rubygems library to be released
  #
  def initialize(version)
    segments = Gem::Version.new(version).segments

    @level = segments[2] != 0 ? :patch : :minor_or_major

    @stable_branch = segments[0, 2].join(".")
    @previous_stable_branch = @level == :minor_or_major ? "#{segments[0]}.#{segments[1] - 1}" : @stable_branch

    rubygems_version = segments.join(".")
    @rubygems = Rubygems.new(rubygems_version, @stable_branch)

    bundler_version = segments.map.with_index {|s, i| i == 0 ? s - 1 : s }.join(".")
    @bundler = Bundler.new(bundler_version, @stable_branch)

    @release_branch = "release/bundler_#{bundler_version}_rubygems_#{rubygems_version}"
  end

  def set_bundler_as_current_library
    @current_library = @bundler
  end

  def set_rubygems_as_current_library
    @current_library = @rubygems
  end

  def prepare!
    initial_branch = `git rev-parse --abbrev-ref HEAD`.strip

    create_if_not_exist_and_switch_to(@stable_branch, from: "master")

    system("git", "push", "origin", @stable_branch, exception: true) if @level == :minor_or_major

    create_if_not_exist_and_switch_to(@release_branch, from: @stable_branch)

    begin
      @bundler.set_relevant_pull_requests_from(unreleased_pull_requests)
      @rubygems.set_relevant_pull_requests_from(unreleased_pull_requests)

      cherry_pick_pull_requests if @level == :patch

      bundler_changelog, rubygems_changelog = cut_changelogs_and_bump_versions

      system("git", "push", exception: true)

      gh_client.create_pull_request(
        "rubygems/rubygems",
        @stable_branch,
        @release_branch,
        "Prepare RubyGems #{@rubygems.version} and Bundler #{@bundler.version}",
        "It's release day!"
      )

      create_if_not_exist_and_switch_to("cherry_pick_changelogs", from: "master")

      begin
        system("git", "cherry-pick", bundler_changelog, rubygems_changelog, exception: true)
        system("git", "push", exception: true)
      rescue StandardError
        system("git", "cherry-pick", "--abort")
      else
        gh_client.create_pull_request(
          "rubygems/rubygems",
          "master",
          "cherry_pick_changelogs",
          "Changelogs for RubyGems #{@rubygems.version} and Bundler #{@bundler.version}",
          "Cherry-picking change logs from future RubyGems #{@rubygems.version} and Bundler #{@bundler.version} into master."
        )
      end
    rescue StandardError
      system("git", "checkout", initial_branch)
      raise
    end
  end

  def create_if_not_exist_and_switch_to(branch, from:)
    system("git", "checkout", branch, exception: true, err: IO::NULL)
  rescue StandardError
    system("git", "checkout", "-b", branch, from, exception: true)
  end

  def cherry_pick_pull_requests
    prs = relevant_unreleased_pull_requests
    raise "No unreleased PRs were found. Make sure to tag them with appropriate labels so that they are selected for backport." unless prs.any?

    puts "The following unreleased prs were found:\n#{prs.map {|pr| "* #{pr.url}" }.join("\n")}"

    unless system("git", "cherry-pick", "-x", "-m", "1", *prs.map(&:merge_commit_sha))
      warn <<~MSG

        Opening a new shell to fix the cherry-pick errors manually. You can do the following now:

        * Find the PR that caused the merge conflict.
        * If you'd like to include that PR in the release, tag it with an appropriate label. Then type `exit 1` and rerun the task so that the PR is cherry-picked before and the conflict is fixed.
        * If you don't want to include that PR in the release, fix conflicts manually, run `git add . && git cherry-pick --continue` once done, and if it succeeds, run `exit 0` to resume the release preparation.

      MSG

      unless system(ENV["SHELL"] || "zsh")
        system("git", "cherry-pick", "--abort", exception: true)
        raise "Failed to resolve conflicts, resetting original state"
      end
    end
  end

  def cut_changelogs_and_bump_versions
    system("git", "branch", "#{@release_branch}-bkp")

    @bundler.cut_changelog!
    system("git", "commit", "-am", "Changelog for Bundler version #{@bundler.version}", exception: true)
    bundler_changelog = `git show --no-patch --pretty=format:%h`

    @bundler.bump_versions!
    system("rake", "update_locked_bundler", exception: true)
    system("git", "commit", "-am", "Bump Bundler version to #{@bundler.version}", exception: true)

    @rubygems.cut_changelog!
    system("git", "commit", "-am", "Changelog for Rubygems version #{@rubygems.version}", exception: true)
    rubygems_changelog = `git show --no-patch --pretty=format:%h`

    @rubygems.bump_versions!
    system("git", "commit", "-am", "Bump Rubygems version to #{@rubygems.version}", exception: true)

    [bundler_changelog, rubygems_changelog]
  rescue StandardError
    system("git", "reset", "--hard", "#{@release_branch}-bkp")
  ensure
    system("git", "branch", "-D", "#{@release_branch}-bkp")
  end

  def cut_changelog!
    @current_library.cut_changelog_for!(unreleased_pull_requests)
  end

  def create_for_github!
    @current_library.create_for_github!
  end

  private

  def relevant_unreleased_pull_requests
    (@bundler.relevant_pull_requests + @rubygems.relevant_pull_requests).uniq.sort_by(&:merged_at)
  end

  def unreleased_pull_requests
    @unreleased_pull_requests ||= scan_unreleased_pull_requests(unreleased_pr_ids)
  end

  def scan_unreleased_pull_requests(ids)
    pulls = gh_client.pull_requests("rubygems/rubygems", sort: :updated, state: :closed, direction: :desc)

    loop do
      pulls.select! {|pull| ids.include?(pull.number) }

      break if (pulls.map(&:number) & ids).to_set == ids.to_set

      pulls.concat gh_client.get(gh_client.last_response.rels[:next].href)
    end

    pulls
  end

  def unreleased_pr_ids
    stable_merge_commit_messages = `git log --format=%s --grep "^Merge pull request #" #{@previous_stable_branch}`.split("\n")

    `git log --oneline --grep "^Merge pull request #" origin/master`.split("\n").map do |l|
      _sha, message = l.split(/\s/, 2)

      next if stable_merge_commit_messages.include?(message)

      /^Merge pull request #(\d+)/.match(message)[1].to_i
    end.compact
  end
end
