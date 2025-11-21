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

      options = {
        name: tag,
        body: @changelog.release_notes.join("\n").strip,
        prerelease: @version.prerelease?,
      }
      options[:target_commitish] = @stable_branch unless @version.prerelease?

      gh_client.create_release "ruby/rubygems", tag, **options
    end

    def previous_version
      @previous_version ||= remove_tag_prefix(latest_release.tag_name)
    end

    def latest_release
      @latest_release ||= gh_client.releases("ruby/rubygems").select {|release| release.tag_name.start_with?(@tag_prefix) }.max_by do |release|
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
      if version.segments[0] >= 4
        version.to_s.gsub(/([a-z])\.(\d)/i, '\1\2')
      else
        version.segments.map.with_index {|s, i| i == 0 ? s - 1 : s }.join(".")
      end
    end
  end

  include GithubAPI

  def self.install_dependencies!
    system(
      { "RUBYOPT" => "-I#{File.expand_path("../lib", __dir__)}" },
      File.expand_path("../bundler/bin/bundle", __dir__),
      "install",
      "--gemfile=#{File.expand_path("bundler/release_gems.rb", __dir__)}",
      exception: true
    )

    Gem.clear_paths
  end

  def self.for_bundler(version)
    segments = Gem::Version.new(version).segments
    rubygems_version = if segments[0] >= 4
      segments.join(".")
    else
      segments.map.with_index {|s, i| i == 0 ? s + 1 : s }.join(".")
    end

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
    @previous_stable_branch = "3.7" if @stable_branch == "4.0"

    @previous_release_tag = if @level == :minor_or_major
      "v#{@previous_stable_branch}.0"
    else
      `git describe --tags --abbrev=0`.strip
    end

    rubygems_version = segments.join(".").gsub(/([a-z])\.(\d)/i, '\1\2')
    @rubygems = Rubygems.new(rubygems_version, @stable_branch)

    bundler_version = if segments[0] >= 4
      segments.join(".")
    else
      segments.map.with_index {|s, i| i == 0 ? s - 1 : s }.join(".")
    end
    bundler_version = bundler_version.gsub(/([a-z])\.(\d)/i, '\1\2')

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
        "ruby/rubygems",
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
          "ruby/rubygems",
          "master",
          "cherry_pick_changelogs",
          "Changelogs for RubyGems #{@rubygems.version} and Bundler #{@bundler.version}",
          "Cherry-picking change logs from future RubyGems #{@rubygems.version} and Bundler #{@bundler.version} into master."
        )
      end
    rescue StandardError, LoadError
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
    system("bin/rake", "version:update_locked_bundler", exception: true)
    system("git", "commit", "-am", "Bump Bundler version to #{@bundler.version}", exception: true)

    @rubygems.cut_changelog!
    system("git", "commit", "-am", "Changelog for Rubygems version #{@rubygems.version}", exception: true)
    rubygems_changelog = `git show --no-patch --pretty=format:%h`

    @rubygems.bump_versions!
    system("git", "commit", "-am", "Bump Rubygems version to #{@rubygems.version}", exception: true)

    [bundler_changelog, rubygems_changelog]
  rescue StandardError
    system("git", "reset", "--hard", "#{@release_branch}-bkp")

    raise
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
    ids.map {|id| gh_client.pull_request("ruby/rubygems", id) }
  end

  def unreleased_pr_ids
    commits = `git log --format=%h #{@previous_release_tag}..HEAD`.split("\n")

    # GitHub search API has a rate limit of 30 requests per minute for authenticated users
    rate_limit = 28
    # GitHub search API only accepts 250 characters per search query
    batch_size = 15
    sleep_duration = 60 # seconds

    pr_ids = Set.new

    commits.each_slice(batch_size).with_index do |batch, index|
      puts "Processing batch #{index + 1}/#{(commits.size / batch_size.to_f).ceil}"
      result = `gh search prs --repo ruby/rubygems #{batch.join(",")} --json number --jq '.[].number'`.strip
      unless result.empty?
        result.split("\n").each {|pr_number| pr_ids.add(pr_number.to_i) }
      end

      if index != 0 && index % rate_limit == 0
        puts "Sleeping for #{sleep_duration} seconds to avoid rate limiting..."
        sleep(sleep_duration)
      end
    end

    pr_ids.to_a
  end
end
