# frozen_string_literal: true

require_relative "../vendored_fileutils"

module Bundler
  class CompactIndexClient
    class Updater
      # TODO: support more algorithms, at least sha-512
      SUPPORTED_DIGESTS = ['sha-256']

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

      def update(local_path, remote_path, retrying = nil, local_etag_path = nil)
        headers = {}

        local_temp_path = local_path.sub(/$/, ".#{$$}")
        local_temp_path = local_temp_path.sub(/$/, ".retrying") if retrying
        local_etag_temp_path = local_temp_path.sub(/$/, ".etag.tmp")
        local_temp_path = local_temp_path.sub(/$/, ".tmp")

        # first try to fetch any new bytes on the existing file
        if retrying.nil? && local_path.file? && local_etag_path.file?
          copy_file local_path, local_temp_path
          copy_file local_etag_path, local_etag_temp_path if local_etag_path

          headers["If-None-Match"] = local_etag_temp_path.read if local_etag_path
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
        # TODO: support Repr-Digest as well
        response_digests = parse_digest_list(response["Digest"])
        supported_digest = response_digests.find {|digest| SUPPORTED_DIGESTS.include?(digest.algorithm)}

        correct_response = SharedHelpers.filesystem_access(local_temp_path) do
          if response.is_a?(Net::HTTPPartialContent) && local_temp_path.size.nonzero?
            local_temp_path.open("a") {|f| f << slice_body(content, 1..-1) }
            local_etag_temp_path.open("wb") {|f| f << etag } if local_etag_path
          else
            local_temp_path.open("wb") {|f| f << content }
            local_etag_temp_path.open("wb") {|f| f << etag } if local_etag_path
          end

          if supported_digest
            supported_digest.value == digest_for_file(supported_digest.algorithm, local_temp_path)
          else
            # no supported digest found, no checksum check
            true
          end
        end

        if correct_response
          SharedHelpers.filesystem_access(local_path) do
            FileUtils.mv(local_temp_path, local_path)
          end
          SharedHelpers.filesystem_access(local_etag_path) do
            FileUtils.mv(local_etag_temp_path, local_etag_path)
          end if local_etag_path

          return nil
        end

        if retrying
          raise MisMatchedChecksumError.new(remote_path, supported_digest.value, digest_for_file(supported_digest.algorithm, local_temp_path))
        end

        update(local_path, remote_path, :retrying)
      rescue Zlib::GzipFile::Error
        raise Bundler::HTTPError
      ensure
        FileUtils.remove_file(local_temp_path) if File.exist?(local_temp_path)
        FileUtils.remove_file(local_etag_temp_path) if local_etag_temp_path && File.exist?(local_etag_temp_path)
      end

      def slice_body(body, range)
        body.byteslice(range)
      end

      def digest_for_file(algorithm, path)
        return nil unless path.file?
        return nil unless SUPPORTED_DIGESTS.include?(algorithm)

        SharedHelpers.digest(:SHA256).base64digest(File.read(path))
      end

      def checksum_for_file(path)
        return nil unless path.file?
        # This must use File.read instead of Digest.file().hexdigest
        # because we need to preserve \n line endings on windows when calculating
        # the checksum
        SharedHelpers.filesystem_access(path, :read) do
          SharedHelpers.digest(:MD5).hexdigest(File.read(path))
        end
      end

      private

      def copy_file(source, dest)
        SharedHelpers.filesystem_access(source, :read) do
          File.open(source, "r") do |s|
            SharedHelpers.filesystem_access(dest, :write) do
              File.open(dest, "wb", s.stat.mode) do |f|
                IO.copy_stream(s, f)
              end
            end
          end
        end
      end

      ResponseDigest = Struct.new(:algorithm, :value)

      def parse_digest_list(header)
        [].tap do |digest_list|

          # Split the header by commas
          header.split(',').each do |param|
            # split only on first `=` sign
            parts = param.split('=', 2)
            algorithm = parts[0].strip
            value = parts[1]

            # unwrap surrounding quotes if present
            if value.start_with?('"') && value.end_with?('"')
              value = value[1..-2]
            end

            digest_list << ResponseDigest.new(algorithm, value)
          end
        end
      end
    end
  end
end
