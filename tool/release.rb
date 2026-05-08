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
      @version_files = [File.expand_path("../lib/rubygems.rb", __dir__)]
      @tag_prefix = "v"
    end

    def extra_entry
      "Installs bundler #{@version} as a default gem"
    end
  end

  include GithubAPI

  def self.install_dependencies!
    system(
      { "RUBYOPT" => "-I#{File.expand_path("../lib", __dir__)}" },
      File.expand_path("../bin/bundle", __dir__),
      "install",
      "--gemfile=#{File.expand_path("bundler/release_gems.rb", __dir__)}",
      exception: true
    )

    Gem.clear_paths
  end

  def self.for_bundler(version)
    release = new(version)
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
    @prerelease = segments.size > 3

    @stable_branch = segments[0, 2].join(".")
    @previous_stable_branch = @level == :minor_or_major ? "#{segments[0]}.#{segments[1] - 1}" : @stable_branch
    @previous_stable_branch = "3.7" if @stable_branch == "4.0"

    @previous_release_tag = if @level == :minor_or_major
      if @prerelease
        `git describe --tags --abbrev=0`.strip
      else
        "v#{@previous_stable_branch}.0"
      end
    else
      "v#{@stable_branch}.0"
    end

    rubygems_version = segments.join(".").gsub(/([a-z])\.(\d)/i, '\1\2')
    @rubygems = Rubygems.new(rubygems_version, @stable_branch)

    bundler_version = segments.join(".").gsub(/([a-z])\.(\d)/i, '\1\2')
    @bundler = Bundler.new(bundler_version, @stable_branch)

    @release_branch = "release/#{version}"
  end

  def set_bundler_as_current_library
    @current_library = @bundler
  end

  def set_rubygems_as_current_library
    @current_library = @rubygems
  end

  def prepare!
    initial_branch = `git rev-parse --abbrev-ref HEAD`.strip

    check_git_state!

    unless @prerelease
      create_if_not_exist_and_switch_to(@stable_branch, from: "master")
      system("git", "push", "origin", @stable_branch, exception: true) if @level == :minor_or_major && !ENV["DRYRUN"]
    end

    from_branch = if @level == :minor_or_major && @prerelease
      "master"
    else
      @stable_branch
    end
    create_if_not_exist_and_switch_to(@release_branch, from: from_branch)

    begin
      @bundler.set_relevant_pull_requests_from(unreleased_pull_requests)
      @rubygems.set_relevant_pull_requests_from(unreleased_pull_requests)

      cherry_pick_pull_requests if @level == :patch

      bundler_changelog, rubygems_changelog = cut_changelogs_and_bump_versions

      system("git", "push", exception: true) unless ENV["DRYRUN"]

      gh_client.create_pull_request(
        "ruby/rubygems",
        from_branch,
        @release_branch,
        "Prepare RubyGems #{@rubygems.version} and Bundler #{@bundler.version}",
        release_pull_request_body
      ) unless ENV["DRYRUN"]

      unless @prerelease
        create_if_not_exist_and_switch_to("cherry_pick_changelogs", from: "master")

        begin
          system("git", "cherry-pick", bundler_changelog, rubygems_changelog, exception: true)
          system("git", "push", exception: true) unless ENV["DRYRUN"]
        rescue StandardError
          system("git", "cherry-pick", "--abort")
        else
          gh_client.create_pull_request(
            "ruby/rubygems",
            "master",
            "cherry_pick_changelogs",
            "Changelogs for RubyGems #{@rubygems.version} and Bundler #{@bundler.version}",
            "Cherry-picking change logs from future RubyGems #{@rubygems.version} and Bundler #{@bundler.version} into master."
          ) unless ENV["DRYRUN"]
        end
      end
    rescue StandardError, LoadError
      system("git", "checkout", initial_branch)
      raise
    end
  end

  def check_git_state!
    git_dir = `git rev-parse --absolute-git-dir`.strip
    errors = []

    if File.exist?(File.join(git_dir, "index.lock"))
      errors << "#{git_dir}/index.lock exists. A previous git process may have crashed. Remove it if no git process is running."
    end

    if File.exist?(File.join(git_dir, "CHERRY_PICK_HEAD"))
      errors << "A cherry-pick is in progress. Run `git cherry-pick --abort` to cancel it."
    end

    if File.exist?(File.join(git_dir, "rebase-merge")) || File.exist?(File.join(git_dir, "rebase-apply"))
      errors << "A rebase is in progress. Run `git rebase --abort` to cancel it."
    end

    branches = [@release_branch]
    branches << "cherry_pick_changelogs" unless @prerelease
    existing = branches.select {|b| system("git", "rev-parse", "--verify", "refs/heads/#{b}", out: IO::NULL, err: IO::NULL) }
    unless existing.empty?
      errors << "Release branches already exist: #{existing.join(", ")}. Please delete them before running this task."
    end

    raise errors.join("\n") unless errors.empty?
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

    prs.each do |pr|
      args = cherry_pick_args_for(pr)
      next if system("git", "cherry-pick", "-x", *args)

      warn <<~MSG

        Cherry-picking #{pr.url} failed. Opening a new shell to fix the errors manually. You can do the following now:

        * If you'd like to include that PR in the release, fix conflicts manually, run `git add . && git cherry-pick --continue` once done, and if it succeeds, run `exit 0` to resume the release preparation.
        * If you don't want to include that PR in the release, run `git cherry-pick --abort` and then `exit 0` to skip it and resume.
        * To abort the entire release preparation, run `exit 1`.

      MSG

      unless system(ENV["SHELL"] || "zsh")
        system("git", "cherry-pick", "--abort")
        raise "Failed to resolve conflicts, resetting original state"
      end
    end
  end

  # Builds the `git cherry-pick` arguments for a PR by detecting which merge
  # strategy GitHub used. PRs merged with "Create a merge commit" are picked
  # with `-m 1` against the merge commit. PRs merged with "Squash and merge"
  # produce a single commit, which is picked directly. PRs merged with
  # "Rebase and merge" produce N linear commits ending at `merge_commit_sha`,
  # so we cherry-pick the full range to avoid silently dropping commits.
  def cherry_pick_args_for(pr)
    sha = pr.merge_commit_sha
    parents = `git rev-list --parents -n 1 #{sha}`.strip.split.drop(1)

    if parents.size >= 2
      ["-m", "1", sha]
    else
      pr_commits = gh_client.pull_request_commits("ruby/rubygems", pr.number)

      if pr_commits.size > 1 && rebase_merged?(sha, pr_commits)
        ["#{sha}~#{pr_commits.size}..#{sha}"]
      else
        [sha]
      end
    end
  end

  def rebase_merged?(sha, pr_commits)
    n = pr_commits.size
    master_subjects = `git log -n #{n} --format=%s #{sha}`.lines.map(&:strip).reverse
    pr_subjects = pr_commits.map {|c| c.commit.message.lines.first.strip }
    master_subjects == pr_subjects
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

  def release_pull_request_body
    prs = relevant_unreleased_pull_requests
    lines = prs.map {|pr| "* #{pr.title} [##{pr.number}](#{pr.html_url})" }
    lines.join("\n")
  end

  def relevant_unreleased_pull_requests
    (@bundler.relevant_pull_requests + @rubygems.relevant_pull_requests).uniq.sort_by(&:merged_at)
  end

  def unreleased_pull_requests
    @unreleased_pull_requests ||= scan_unreleased_pull_requests(unreleased_pr_ids)
  end

  # Source SHAs already cherry-picked onto the stable branch, derived from the
  # `(cherry picked from commit X)` footer that `git cherry-pick -x` records.
  # This is more reliable than matching merge commit subjects, which only
  # catches PRs merged with "Create a merge commit". Squash-merged PRs are
  # cherry-picked as plain commits with subjects like `"Foo (#1234)"` or
  # without any PR reference, so subject-based detection misses them.
  def released_commit_shas
    @released_commit_shas ||= `git log --format=%B #{@previous_release_tag}..#{@stable_branch}`
      .scan(/cherry picked from commit ([0-9a-f]+)/).flatten.to_set
  end

  def scan_unreleased_pull_requests(ids)
    pulls = []
    ids.each do |id|
      pull = gh_client.pull_request("ruby/rubygems", id)
      pulls << pull if pull.merged_at
    end
    pulls
  end

  def unreleased_pr_ids
    head = @level == :minor_or_major ? "HEAD" : "master"
    commits = `git log --format=%H #{@previous_release_tag}..#{head}`.split("\n")
    commits.reject! {|sha| released_commit_shas.include?(sha) } if @level == :patch

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
        result.split("\n").each do |pr_number|
          pr_ids.add(pr_number.to_i)
        end
      end

      if index != 0 && index % rate_limit == 0
        puts "Sleeping for #{sleep_duration} seconds to avoid rate limiting..."
        sleep(sleep_duration)
      end
    end

    pr_ids.to_a
  end
end
