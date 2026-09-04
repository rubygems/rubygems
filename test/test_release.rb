# frozen_string_literal: true

require_relative "../tool/release"
require_relative "rubygems/helper"

class ReleaseTest < Test::Unit::TestCase
  def test_pull_requests_from_maps_a_listing_record_to_the_fields_the_changelog_uses
    pull = release.send(:pull_requests_from, listing([record]), "master since 2026-01-01").first

    assert_equal 9852, pull.number
    assert_equal "Let the gem and bundle cooldown settings cover each other", pull.title
    assert_equal "https://github.com/ruby/rubygems/pull/9852", pull.html_url
    assert_equal ["bundler: bug fix"], pull.labels.map(&:name)
    assert_equal Time.utc(2026, 9, 4, 2, 23, 29), pull.merged_at
    assert_equal "Hiroshi SHIBATA", pull.user.name
    assert_equal "hsbt", pull.user.login
    assert_equal "0602168df08a985b635ea24fb80f9048465f9530", pull.merge_commit_sha
  end

  def test_pull_requests_from_falls_back_to_the_login_when_the_author_has_no_name
    json = listing([record("author" => { "login" => "app/dependabot", "name" => "" })])

    pull = release.send(:pull_requests_from, json, "master since 2026-01-01").first

    assert_nil pull.user.name
    assert_equal "app/dependabot", pull.user.login
  end

  def test_pull_requests_from_refuses_a_truncated_listing
    json = listing(Array.new(Release::MERGED_PULL_REQUEST_LIMIT) { record })

    error = assert_raise(RuntimeError) do
      release.send(:pull_requests_from, json, "master since 2026-01-01")
    end

    assert_include error.message, "truncated"
  end

  def test_pull_requests_merged_into_keeps_only_the_ones_whose_merge_commit_landed
    release = self.release
    landed = "a" * 40
    json = listing([
      record("number" => 1, "mergeCommit" => { "oid" => landed }),
      record("number" => 2, "mergeCommit" => { "oid" => "b" * 40 }),
    ])
    pulls = release.send(:pull_requests_from, json, "master since 2026-01-01")

    release.stub(:`, "#{landed}\n") do
      release.stub(:merged_pull_requests, pulls) do
        assert_equal [1], release.send(:pull_requests_merged_into, "master", "v4.0.0", "HEAD").map(&:number)
      end
    end
  end

  private

  # A minor release, so that the constructor derives the previous release tag
  # from the version instead of shelling out to `git describe`.
  def release
    Release.new("4.1.0")
  end

  def listing(records)
    JSON.dump(records)
  end

  def record(overrides = {})
    {
      "number" => 9852,
      "title" => "Let the gem and bundle cooldown settings cover each other",
      "url" => "https://github.com/ruby/rubygems/pull/9852",
      "labels" => [{ "name" => "bundler: bug fix" }],
      "mergedAt" => "2026-09-04T02:23:29Z",
      "author" => { "login" => "hsbt", "name" => "Hiroshi SHIBATA" },
      "mergeCommit" => { "oid" => "0602168df08a985b635ea24fb80f9048465f9530" },
    }.merge(overrides)
  end
end
