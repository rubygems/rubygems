# frozen_string_literal: true

require_relative "helpers/compact_index"

class CompactIndexChecksumMismatch < CompactIndexAPI
  get "/versions" do
    headers "ETag" => quote("123")
    headers "Digest" => "sha-256=N2bXv5dX2oizwqyjfHIr4DlQXKuctwo0snCf5h6NMj0="
    headers "Surrogate-Control" => "max-age=2592000, stale-while-revalidate=60"
    content_type "text/plain"
    body ""
  end
end

require_relative "helpers/artifice"

Artifice.activate_with(CompactIndexChecksumMismatch)
