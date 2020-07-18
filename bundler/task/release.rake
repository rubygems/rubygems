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

    def sync!
      lines = []

      group_by_labels(pull_requests_since_last_release).each do |label, pulls|
        category = changelog_label_mapping[label]

        lines << "## #{category}"
        lines << ""

        pulls.sort_by(&:merged_at).reverse_each do |pull|
          lines << "  - #{pull.title} [##{pull.number}](#{pull.html_url})"
        end

        lines << ""
      end

      replace_unreleased_notes(lines)
    end

  private

    def group_by_labels(pulls)
      grouped_pulls = pulls.group_by do |pull|
        relevant_label_for(pull)
      end

      grouped_pulls.delete(nil) # exclude non categorized pulls

      grouped_pulls.sort do |a, b|
        changelog_labels.index(a[0]) <=> changelog_labels.index(b[0])
      end.to_h
    end

    def pull_requests_since_last_release
      last_release_date = gh_client.releases("rubygems/rubygems").select {|release| !release.draft && release.tag_name =~ /^bundler-v/ }.sort_by(&:created_at).last.created_at

      pr_ids = merged_pr_ids_since(last_release_date)

      pull_requests_for(pr_ids)
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
      }
    end

    def replace_unreleased_notes(new_content)
      full_new_changelog = [unreleased_section_title, "", new_content, released_notes].join("\n") + "\n"

      File.open("CHANGELOG.md", "w:UTF-8") {|f| f.write(full_new_changelog) }
    end

    def relevant_label_for(pull)
      relevant_labels = pull.labels.map(&:name) & changelog_labels
      return unless relevant_labels.any?

      raise "#{pull.html_url} has multiple labels that map to changelog sections" unless relevant_labels.size == 1

      relevant_labels.first
    end

    def changelog_labels
      changelog_label_mapping.keys
    end

    def merged_pr_ids_since(date)
      commits = `git log --oneline origin/master --since '#{date}'`.split("\n").map {|l| l.split(/\s/, 2) }
      commits.map do |_sha, message|
        match = /Merge pull request #(\d+)/.match(message)
        next unless match

        match[1].to_i
      end.compact
    end

    def pull_requests_for(ids)
      pulls = gh_client.pull_requests("rubygems/rubygems", :sort => :updated, :state => :closed, :direction => :desc)

      loop do
        pulls.select! {|pull| ids.include?(pull.number) }

        return pulls if (pulls.map(&:number) & ids).to_set == ids.to_set

        pulls.concat gh_client.get(gh_client.last_response.rels[:next].href)
      end
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

  desc "Replace the unreleased section in the changelog with up to date content according to merged PRs since the last release"
  task :sync_changelog do
    Changelog.new.sync!
  end

  desc "Prepare a patch release with the PRs from master in the patch milestone"
  task :prepare_patch, :version do |_t, args|
    version = args.version

    version ||= begin
      current_version = Bundler::GemHelper.gemspec.version
      segments = current_version.segments
      if segments.last.is_a?(String)
        segments << "1"
      else
        segments[-1] += 1
      end
      segments.join(".")
    end

    puts "Cherry-picking PRs milestoned for #{version} (currently #{current_version}) into the stable branch..."

    gh_client = GithubInfo.client

    milestones = gh_client.milestones("rubygems/rubygems", :state => "open")

    unless patch_milestone = milestones.find {|m| m["title"] == version }
      abort "failed to find #{version} milestone on GitHub"
    end
    prs = gh_client.issues("rubygems/rubygems", :milestone => patch_milestone["number"], :state => "all")
    prs.map! do |pr|
      abort "#{pr["html_url"]} hasn't been closed yet!" unless pr["state"] == "closed"
      next unless pr["pull_request"]
      pr["number"].to_s
    end
    prs.compact!

    branch = Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join(".")
    sh("git", "checkout", "-b", "release_bundler/#{version}", branch)

    commits = `git log --oneline origin/master`.split("\n").map {|l| l.split(/\s/, 2) }.reverse
    commits.select! {|_sha, message| message =~ /Merge pull request ##{Regexp.union(*prs)}/ }

    abort "Could not find commits for all PRs" unless commits.size == prs.size

    if commits.any? && !system("git", "cherry-pick", "-x", "-m", "1", *commits.map(&:first))
      warn "Opening a new shell to fix the cherry-pick errors. Press Ctrl-D when done to resume the task"

      unless system(ENV["SHELL"] || "zsh")
        abort "Failed to resolve conflicts on a different shell. Resolve conflicts manually and finish the task manually"
      end
    end

    version_file = "lib/bundler/version.rb"
    version_contents = File.read(version_file)
    unless version_contents.sub!(/^(\s*VERSION = )"#{Gem::Version::VERSION_PATTERN}"/, "\\1#{version.to_s.dump}")
      abort "failed to update #{version_file}, is it in the expected format?"
    end
    File.open(version_file, "w") {|f| f.write(version_contents) }

    sh("git", "commit", "-am", "Version #{version}")
  end
end
