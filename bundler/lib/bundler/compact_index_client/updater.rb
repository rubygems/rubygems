# frozen_string_literal: true

require_relative "../vendored_fileutils"
require "rubygems/package"

module Bundler
  class CompactIndexClient
    class Updater
      class MisMatchedChecksumError < Error
        def initialize(path, server_checksum, local_checksum)
          @path = path
          @server_checksum = server_checksum
          @local_checksum = local_checksum
        end

        def message
          "The checksum of /#{@path} does not match the checksum provided by the server! Something is wrong " \
            "(local checksum is #{@local_checksum.inspect}, was expecting #{@server_checksum.inspect})."
        end
      end

      def initialize(fetcher)
        @fetcher = fetcher
      end

      def update(local_path, remote_path, retrying = nil)
        headers = {}

        local_temp_path = local_path.sub(/$/, ".#{$$}")
        local_temp_path = local_temp_path.sub(/$/, ".retrying") if retrying
        local_temp_path = local_temp_path.sub(/$/, ".tmp")

        digests = { :MD5 => SharedHelpers.digest(:MD5).new }

        # first try to fetch any new bytes on the existing file
        if retrying.nil? && local_path.file?
          copy_file local_path, local_temp_path, digests

          headers["If-None-Match"] = etag_for(digests)
          headers["Range"] =
            if local_temp_path.size.nonzero?
              # Subtract a byte to ensure the range won't be empty.
              # Avoids 416 (Range Not Satisfiable) responses.
              "bytes=#{local_temp_path.size - 1}-"
            else
              "bytes=#{local_temp_path.size}-"
            end
        end

        response = @fetcher.call(remote_path, headers)
        return nil if response.is_a?(Net::HTTPNotModified)

        content = response.body

        etag = (response["ETag"] || "").gsub(%r{\AW/}, "")
        correct_response = SharedHelpers.filesystem_access(local_temp_path) do
          if response.is_a?(Net::HTTPPartialContent) && local_temp_path.size.nonzero?
            local_temp_path.open("a") {|f| digest_io(f, digests).write slice_body(content, 1..-1) }

            etag_for(digests) == etag
          else
            digests[:MD5] = SharedHelpers.digest(:MD5).new
            local_temp_path.open("wb") {|f| digest_io(f, digests).write content }

            etag.length.zero? || etag_for(digests) == etag
          end
        end

        if correct_response
          SharedHelpers.filesystem_access(local_path) do
            FileUtils.mv(local_temp_path, local_path)
          end
          return nil
        end

        if retrying
          raise MisMatchedChecksumError.new(remote_path, etag, etag_for(digests))
        end

        update(local_path, remote_path, :retrying)
      rescue Zlib::GzipFile::Error
        raise Bundler::HTTPError
      ensure
        FileUtils.remove_file(local_temp_path) if File.exist?(local_temp_path)
      end

      def etag_for(digests)
        %("#{digests[:MD5].hexdigest}")
      end

      def digest_io(io, digests)
        Gem::Package::DigestIO.new(io, digests)
      end

      def slice_body(body, range)
        body.byteslice(range)
      end

      def checksum_for_file(path)
        SharedHelpers.checksum_for_file(path, :MD5)
      end

      private

      def copy_file(source, dest, digests)
        SharedHelpers.filesystem_access(source, :read) do
          File.open(source, "r") do |s|
            SharedHelpers.filesystem_access(dest, :write) do
              File.open(dest, "wb", s.stat.mode) do |f|
                IO.copy_stream(s, digest_io(f, digests))
              end
            end
          end
        end
      end
    end
  end
end
