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
task "release:rubygem_push" => ["release:verify_docs", "release:verify_github", "build_metadata", "release:github"]

namespace :release do
  task :verify_docs => :"man:check"

  class Changelog
    def release_notes(version)
      current_version_title = "#{section_token}#{version}"
      current_minor_title = "#{section_token}#{version.segments[0, 2].join(".")}"

      current_version_index = lines.find_index {|line| line.strip =~ /^#{current_version_title}($|\b)/ }
      unless current_version_index
        raise "Update the changelog for the last version (#{version})"
      end
      current_version_index += 1
      previous_version_lines = lines[current_version_index.succ...-1]
      previous_version_index = current_version_index + (
        previous_version_lines.find_index {|line| line.start_with?(section_token) && !line.start_with?(current_minor_title) } ||
        lines.count
      )

      lines[current_version_index..previous_version_index].join("\n").strip
    end

    def replace_unreleased_notes(new_content)
      full_new_changelog = [unreleased_section_title, "", new_content, released_notes].join("\n") + "\n")

      File.open("CHANGELOG.md", "w:UTF-8") {|f| f.write(full_new_changelog) }
    end

  private

    def unreleased_section_title
      "#{section_token}(Unreleased)"
    end

    def released_notes
      lines.drop_while {|line| line == unreleased_section_title || !line.start_with?(section_token) }
    end

    def lines
      @lines ||= content.split("\n")
    end

    def content
      File.open("CHANGELOG.md", "r:UTF-8", &:read)
    end

    def section_token
      "## "
    end
  end

  def gh_api_authenticated_request(opts)
    require "netrc"
    require "net/http"
    require "json"
    _username, token = Netrc.read["api.github.com"]

    host = opts.fetch(:host) { "https://api.github.com/" }
    path = opts.fetch(:path)
    uri = URI.join(host, path)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/vnd.github.v3+json",
      "Authorization" => "token #{token}",
    }.merge(opts.fetch(:headers, {}))
    body = opts.fetch(:body) { nil }

    response = if body
      Net::HTTP.post(uri, body.to_json, headers)
    else
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.request_uri)
      headers.each {|k, v| req[k] = v }
      http.request(req)
    end

    if response.code.to_i >= 400
      raise "#{uri}\n#{response.inspect}\n#{begin
                                              JSON.parse(response.body)
                                            rescue JSON::ParseError
                                              response.body
                                            end}"
    end
    JSON.parse(response.body)
  end

  desc "Make sure github API is ready to be used"
  task :verify_github do
    gh_api_authenticated_request :path => "/user"
  end

  def gh_api_request(opts)
    require "net/http"
    require "json"
    host = opts.fetch(:host) { "https://api.github.com/" }
    path = opts.fetch(:path)
    response = Net::HTTP.get_response(URI.join(host, path))

    links = Hash[*(response["Link"] || "").split(", ").map do |link|
      href, name = link.match(/<(.*?)>; rel="(\w+)"/).captures

      [name.to_sym, href]
    end.flatten]

    parsed_response = JSON.parse(response.body)

    if n = links[:next]
      parsed_response.concat gh_api_request(:host => host, :path => n)
    end

    parsed_response
  end

  desc "Push the release to Github releases"
  task :github do
    version = Gem::Version.new(Bundler::GemHelper.gemspec.version)
    release_notes = Changelog.new.release_notes(version)
    tag = "bundler-v#{version}"

    gh_api_authenticated_request :path => "/repos/rubygems/rubygems/releases",
                                 :body => {
                                   :tag_name => tag,
                                   :name => tag,
                                   :body => release_notes,
                                   :prerelease => version.prerelease?,
                                 }
  end

  desc "Prints the current version in the version file, which should be the next release target"
  task :target_version do
    print Bundler::GemHelper.gemspec.version
  end

  desc "Replace the unreleased section in the changelog with new content. Pass the new content through ENV['NEW_CHANGELOG_CONTENT']"
  task :write_changelog do
    new_content = ENV["NEW_CHANGELOG_CONTENT"]
    raise "You need to pass some content to write through ENV['NEW_CHANGELOG_CONTENT']" unless new_content

    Changelog.new.replace_unreleased_notes(new_content)
  end

  desc "Prepare a patch release with the PRs from master in the patch milestone"
  task :prepare_patch, :version do |_t, args|
    version = args.version
    current_version = Bundler::GemHelper.gemspec.version

    version ||= begin
      segments = current_version.segments
      if segments.last.is_a?(String)
        segments << "1"
      else
        segments[-1] += 1
      end
      segments.join(".")
    end

    puts "Cherry-picking PRs milestoned for #{version} (currently #{current_version}) into the stable branch..."

    milestones = gh_api_request(:path => "repos/rubygems/rubygems/milestones?state=open")
    unless patch_milestone = milestones.find {|m| m["title"] == version }
      abort "failed to find #{version} milestone on GitHub"
    end
    prs = gh_api_request(:path => "repos/rubygems/rubygems/issues?milestone=#{patch_milestone["number"]}&state=all")
    prs.map! do |pr|
      abort "#{pr["html_url"]} hasn't been closed yet!" unless pr["state"] == "closed"
      next unless pr["pull_request"]
      pr["number"].to_s
    end
    prs.compact!

    branch = Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join(".")
    sh("git", "checkout", "-b", "release_bundler/#{version}", branch)

    commits = `git log --oneline origin/master -- bundler`.split("\n").map {|l| l.split(/\s/, 2) }.reverse
    commits.select! {|_sha, message| message =~ /(Auto merge of|Merge pull request|Merge) ##{Regexp.union(*prs)}/ }

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
