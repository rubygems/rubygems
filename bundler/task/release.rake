# frozen_string_literal: true

require_relative "../lib/bundler/gem_tasks"
require_relative "../spec/support/build_metadata"

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

  class Changelog
    def initialize(level = nil)
      @level = level
    end

    def release_notes(version)
      current_version_title = "#{release_section_token}#{version}"
      current_minor_title = "#{release_section_token}#{version.segments[0, 2].join(".")}"

      current_version_index = lines.find_index {|line| line.strip =~ /^#{current_version_title}($|\b)/ }
      unless current_version_index
        raise "Update the changelog for the last version (#{version})"
      end
      current_version_index += 1
      previous_version_lines = lines[current_version_index.succ...-1]
      previous_version_index = current_version_index + (
        previous_version_lines.find_index {|line| line.start_with?(release_section_token) && !line.start_with?(current_minor_title) } ||
        lines.count
      )

      join_and_strip(lines[current_version_index..previous_version_index])
    end

    def cut!(version)
      full_new_changelog = [
        unreleased_section_title,
        "",
        "# #{version} (#{Time.now.strftime("%B %-d, %Y")})",
        "",
        unreleased_notes,
        lines,
      ].join("\n") + "\n"

      File.write("CHANGELOG.md", full_new_changelog)
    end

    def unreleased_notes
      lines = []

      group_by_labels(relevant_pull_requests_since_last_release).each do |label, pulls|
        category = changelog_label_mapping[label]

        lines << "## #{category}"
        lines << ""

        pulls.reverse_each do |pull|
          lines << "  - #{pull.title} [##{pull.number}](#{pull.html_url})"
        end

        lines << ""
      end

      lines
    end

    def relevant_pull_requests_since_last_release
      last_release_date = GithubInfo.latest_release.created_at

      pr_ids = merged_pr_ids_since(last_release_date)

      relevant_pull_requests_for(pr_ids)
    end

  private

    def group_by_labels(pulls)
      grouped_pulls = pulls.group_by do |pull|
        relevant_label_for(pull)
      end

      grouped_pulls.delete_if {|k, _v| changelog_label_mapping[k].nil? }

      grouped_pulls.sort do |a, b|
        changelog_labels.index(a[0]) <=> changelog_labels.index(b[0])
      end.to_h
    end

    def changelog_label_mapping
      {
        "bundler: security fix" => "Security fixes:",
        "bundler: breaking change" => "Breaking changes:",
        "bundler: major enhancement" => "Major enhancements:",
        "bundler: deprecation" => "Deprecations:",
        "bundler: feature" => "Features:",
        "bundler: performance" => "Performance:",
        "bundler: documentation" => "Documentation:",
        "bundler: minor enhancement" => "Minor enhancements:",
        "bundler: bug fix" => "Bug fixes:",
        "bundler :backport" => nil,
      }
    end

    def relevant_label_for(pull)
      relevant_labels = pull.labels.map(&:name) & changelog_labels
      return unless relevant_labels.any?

      raise "#{pull.html_url} has multiple labels that map to changelog sections" unless relevant_labels.size == 1

      relevant_labels.first
    end

    def patch_level_labels
      ["bundler: security fix", "bundler: minor enhancement", "bundler: bug fix", "bundler: backport"]
    end

    def changelog_labels
      if @level == :patch
        patch_level_labels
      else
        changelog_label_mapping.keys
      end
    end

    def merged_pr_ids_since(date)
      commits = `git log --oneline origin/master --since '#{date}'`.split("\n").map {|l| l.split(/\s/, 2) }
      commits.map do |_sha, message|
        match = /Merge pull request #(\d+)/.match(message)
        next unless match

        match[1].to_i
      end.compact
    end

    def relevant_pull_requests_for(ids)
      pulls = gh_client.pull_requests("rubygems/rubygems", :sort => :updated, :state => :closed, :direction => :desc)

      loop do
        pulls.select! {|pull| ids.include?(pull.number) }

        break if (pulls.map(&:number) & ids).to_set == ids.to_set

        pulls.concat gh_client.get(gh_client.last_response.rels[:next].href)
      end

      pulls.select {|pull| relevant_label_for(pull) }.sort_by(&:merged_at)
    end

    def unreleased_section_title
      "#{release_section_token}(Unreleased)"
    end

    def released_notes
      lines.drop_while {|line| !line.start_with?(release_section_token) }
    end

    def join_and_strip(lines)
      lines.join("\n").strip
    end

    def lines
      @lines ||= content.split("\n")[2..-1]
    end

    def content
      File.open("CHANGELOG.md", "r:UTF-8", &:read)
    end

    def release_section_token
      "# "
    end

    def gh_client
      GithubInfo.client
    end
  end

  module GithubInfo
    extend self

    def latest_release
      @latest_release ||= client.releases("rubygems/rubygems").select {|release| !release.draft && release.tag_name =~ /^bundler-v/ }.sort_by(&:created_at).last
    end

    def client
      @client ||= begin
        require "netrc"
        _username, token = Netrc.read["api.github.com"]

        require "octokit"
        Octokit::Client.new(:access_token => token)
      end
    end
  end

  desc "Push the release to Github releases"
  task :github do
    version = Gem::Version.new(Bundler::GemHelper.gemspec.version)
    release_notes = Changelog.new.release_notes(version)
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
    changelog = Changelog.new(:patch)

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
