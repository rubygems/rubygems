# frozen_string_literal: true

require_relative "helpers/compact_index"

class CompactIndexPartialUpdate < CompactIndexAPI
  # Stub the server to never return 304s. This simulates the behaviour of
  # Fastly / Rubygems ignoring ETag headers.
  def not_modified?(_checksum)
    false
  end

  get "/versions" do
    cached_versions_path = File.join(
      Bundler.rubygems.user_home, ".bundle", "cache", "compact_index",
      "localgemserver.test.80.dd34752a738ee965a2a4298dc16db6c5", "versions"
    )
    content = File.binread(cached_versions_path)

    # Verify a cached copy of the versions file exists
    unless content.start_with?("created_at: ")
      raise("Cached versions file should be present and have content")
    end

    # Verify that a partial request is made, starting from the index of the
    # final byte of the cached file.
    unless env["HTTP_RANGE"] == "bytes=#{content.bytesize - 1}-"
      raise("Range header should be present, and start from the index of the final byte of the cache.")
    end

    # it's possible for a server to return a larger range than requested as long as it satisfies the range request
    start_range = content.bytesize - 8
    header "Content-Range", "bytes #{start_range}-#{content.bytesize}/#{content.bytesize}"
    env["HTTP_RANGE"] = "bytes=#{start_range}-" # trick the artifice so we don't have to re-implement the range parsing

    etag_response do
      # Return the exact contents of the cache.
      File.binread(cached_versions_path)
    end
  end
end

require_relative "helpers/artifice"

Artifice.activate_with(CompactIndexPartialUpdate)
