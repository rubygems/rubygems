# frozen_string_literal: true

require "net/http"
require "bundler/compact_index_client"
require "bundler/compact_index_client/updater"
require "tmpdir"

RSpec.describe Bundler::CompactIndexClient::Updater do
  let(:fetcher) { double(:fetcher) }
  let(:local_path) { Pathname.new Dir.mktmpdir("localpath") }
  let(:remote_path) { double(:remote_path) }

  let!(:updater) { described_class.new(fetcher) }

  context "when the ETag, digest and X-Checksum-sha265 headers are missing" do
    # Regression test for https://github.com/rubygems/bundler/issues/5463
    let(:response) { double(:response, :body => "abc123") }

    it "treats the response as an update" do
      allow(response).to receive(:[]).with("Digest") { nil }
      allow(response).to receive(:[]).with("X-Checksum-Sha256") { nil }
      expect(fetcher).to receive(:call) { response }

      updater.update(local_path, remote_path)

      expect(response).to have_received(:[]).with("Digest")
      expect(response).to have_received(:[]).with("X-Checksum-Sha256")
    end
  end

  context "when the digest header is present" do
    let(:response) { double(:response, :body => "abc123") }

    it "verifies the digest" do
      allow(response).to receive(:[]).with("Digest") { 'sha-256="bKE9UspwyIPg8LsQHkJaiehiTeUdstI5JZOvaoQRgJA="' }
      expect(fetcher).to receive(:call) { response }

      updater.update(local_path, remote_path)

      expect(response).to have_received(:[]).with("Digest")
    end

    it "accepts unquoted digest" do
      allow(response).to receive(:[]).with("Digest") { 'sha-256=bKE9UspwyIPg8LsQHkJaiehiTeUdstI5JZOvaoQRgJA=' }
      expect(fetcher).to receive(:call) { response }

      updater.update(local_path, remote_path)

      expect(response).to have_received(:[]).with("Digest")
    end

    it "raises an error on the sha256 digest mismatch" do
      allow(response).to receive(:[]).with("Digest") { 'sha-256="N2bXv5dX2oizwqyjfHIr4DlQXKuctwo0snCf5h6NMj0="' }
      expect(fetcher).to receive(:call).twice { response }

      expect { updater.update(local_path, remote_path) }.to raise_error(Bundler::CompactIndexClient::Updater::MisMatchedChecksumError)
    end
  end

  context "when the x-checksum-sha256 header is present" do
    let(:response) { double(:response, :body => "abc123") }

    it "verifies the digest" do
      allow(response).to receive(:[]).with("Digest") { nil }
      allow(response).to receive(:[]).with("X-Checksum-Sha256") { "6ca13d52ca70c883e0f0bb101e425a89e8624de51db2d2392593af6a84118090" }
      expect(fetcher).to receive(:call) { response }

      updater.update(local_path, remote_path)

      expect(response).to have_received(:[]).with("Digest")
      expect(response).to have_received(:[]).with("X-Checksum-Sha256")
    end


    it "raises an error on the sha256 digest mismatch" do
      allow(response).to receive(:[]).with("X-Checksum-Sha256") { "bfb9bf6a3e7a783ff953ce150d2a222a0e838529372c326f604d98fa521de1cd" }
      allow(response).to receive(:[]).with("Digest") { nil }
      expect(fetcher).to receive(:call).twice { response }

      expect { updater.update(local_path, remote_path) }.to raise_error(Bundler::CompactIndexClient::Updater::MisMatchedChecksumError)
    end
  end

  context "when the download is corrupt" do
    let(:response) { double(:response, :body => "") }

    it "raises HTTPError" do
      expect(fetcher).to receive(:call).and_raise(Zlib::GzipFile::Error)

      expect do
        updater.update(local_path, remote_path)
      end.to raise_error(Bundler::HTTPError)
    end
  end

  context "when receiving non UTF-8 data and default internal encoding set to ASCII" do
    let(:response) { double(:response, :body => "\x8B".b) }

    it "works just fine" do
      old_verbose = $VERBOSE
      previous_internal_encoding = Encoding.default_internal

      begin
        $VERBOSE = false
        Encoding.default_internal = "ASCII"
        allow(response).to receive(:[]).with("Digest") { nil }
        allow(response).to receive(:[]).with("X-Checksum-Sha256") { nil }
        expect(fetcher).to receive(:call) { response }

        updater.update(local_path, remote_path)

        expect(response).to have_received(:[]).with("X-Checksum-Sha256")
      ensure
        Encoding.default_internal = previous_internal_encoding
        $VERBOSE = old_verbose
      end
    end
  end
end
