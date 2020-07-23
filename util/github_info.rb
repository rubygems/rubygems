# frozen_string_literal: true

module GithubInfo
  extend self

  def latest_release_for(library)
    tag_prefix = library == "bundler" ? "bundler-v" : "v"

    client.releases("rubygems/rubygems").select {|release| release.tag_name.start_with?(tag_prefix) }.sort_by(&:created_at).last
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
