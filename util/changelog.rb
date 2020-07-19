# frozen_string_literal: true

require_relative "github_info"
require "yaml"

class Changelog
  def self.bundler
    @bundler ||= new(
      "CHANGELOG.md",
    )
  end

  def self.bundler_patch_level
    @bundler_patch_level ||= new(
      "CHANGELOG.md",
      :patch,
    )
  end

  def initialize(file, level = :all)
    @file = File.expand_path(file)
    @config = YAML.load_file("#{File.dirname(file)}/.changelog.yml")
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

    lines[current_version_index..previous_version_index]
  end

  def cut!(version)
    full_new_changelog = [
      format_header_for(version),
      "",
      unreleased_notes,
      lines,
    ].join("\n") + "\n"

    File.write(@file, full_new_changelog)
  end

  def unreleased_notes
    lines = []

    group_by_labels(relevant_pull_requests_since_last_release).each do |label, pulls|
      category = changelog_label_mapping[label]

      lines << category
      lines << ""

      pulls.reverse_each do |pull|
        lines << format_entry_for(pull)
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

  def format_header_for(version)
    new_header = header_template.gsub(/%new_version/, version.to_s)

    if header_template.include?("%release_date")
      new_header = new_header.gsub(/%release_date/, Time.now.strftime(release_date_format))
    end

    new_header
  end

  def format_entry_for(pull)
    entry_template
      .gsub(/%pull_request_title/, pull.title)
      .gsub(/%pull_request_number/, pull.number.to_s)
      .gsub(/%pull_request_url/, pull.html_url)
      .gsub(/%pull_request_author/, pull.user.name || pull.user.login)
  end

  def group_by_labels(pulls)
    grouped_pulls = pulls.group_by do |pull|
      relevant_label_for(pull)
    end

    grouped_pulls.delete_if {|k, _v| changelog_label_mapping[k].nil? }

    grouped_pulls.sort do |a, b|
      changelog_labels.index(a[0]) <=> changelog_labels.index(b[0])
    end.to_h
  end

  def relevant_label_for(pull)
    relevant_labels = pull.labels.map(&:name) & changelog_labels
    return unless relevant_labels.any?

    raise "#{pull.html_url} has multiple labels that map to changelog sections" unless relevant_labels.size == 1

    relevant_labels.first
  end

  def relevant_changelog_label_mapping
    mapping = changelog_label_mapping

    mapping = mapping.slice(*patch_level_labels) if @level == :patch

    mapping
  end

  def changelog_labels
    relevant_changelog_label_mapping.keys
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

  def released_notes
    lines.drop_while {|line| !line.start_with?(release_section_token) }
  end

  def lines
    @lines ||= content.split("\n")
  end

  def content
    File.read(@file)
  end

  def release_section_token
    header_template.match(/^(\S+\s+)/)[1]
  end

  def header_template
    @config["header_template"]
  end

  def entry_template
    @config["entry_template"]
  end

  def release_date_format
    @config["release_date_format"]
  end

  def changelog_label_mapping
    @config["changelog_label_mapping"]
  end

  def patch_level_labels
    @config["patch_level_labels"]
  end

  def gh_client
    GithubInfo.client
  end
end
