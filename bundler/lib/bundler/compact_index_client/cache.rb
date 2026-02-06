# frozen_string_literal: true

require "rubygems/resolver/api_set/gem_parser"
require_relative "../io_trace"

module Bundler
  class CompactIndexClient
    class Cache
      attr_reader :directory

      def initialize(directory, fetcher = nil)
        @directory = Pathname.new(directory).expand_path
        @updater = Updater.new(fetcher) if fetcher
        @mutex = Thread::Mutex.new
        @endpoints = Set.new

        @info_root = mkdir("info")
        @special_characters_info_root = mkdir("info-special-characters")
        @info_etag_root = mkdir("info-etags")
      end

      def names
        fetch("names", names_path, names_etag_path)
      end

      def versions
        fetch("versions", versions_path, versions_etag_path)
      end

      def info(name, remote_checksum = nil)
        path = info_path(name)

        if remote_checksum
          # OPTIMIZATION: Read the file once for both checksum verification and data return.
          # Previously, SharedHelpers.checksum_for_file would read the file for MD5,
          # and then read() would read it again if the checksum matched. Now we read
          # once and compute MD5 from the in-memory data.
          data = read(path)
          if data
            local_checksum = SharedHelpers.digest(:MD5).hexdigest(data)
            if remote_checksum != local_checksum
              IOTrace.trace(:http, "compact_index info checksum mismatch, fetching: #{name}") do
                fetch("info/#{name}", path, info_etag_path(name))
              end
            else
              Bundler::CompactIndexClient.debug { "update skipped info/#{name} (versions index checksum matches local)" }
              IOTrace.note(:file_read, "compact_index info cache hit: #{name}")
              data
            end
          else
            fetch("info/#{name}", path, info_etag_path(name))
          end
        else
          Bundler::CompactIndexClient.debug { "update skipped info/#{name} (versions index checksum is nil)" }
          read(path)
        end
      end

      def reset!
        @mutex.synchronize { @endpoints.clear }
      end

      private

      def names_path = directory.join("names")
      def names_etag_path = directory.join("names.etag")
      def versions_path = directory.join("versions")
      def versions_etag_path = directory.join("versions.etag")

      def info_path(name)
        name = name.to_s
        # TODO: converge this into the info_root by hashing all filenames like info_etag_path
        if /[^a-z0-9_-]/.match?(name)
          name += "-#{SharedHelpers.digest(:MD5).hexdigest(name).downcase}"
          @special_characters_info_root.join(name)
        else
          @info_root.join(name)
        end
      end

      def info_etag_path(name)
        name = name.to_s
        @info_etag_root.join("#{name}-#{SharedHelpers.digest(:MD5).hexdigest(name).downcase}")
      end

      def mkdir(name)
        directory.join(name).tap do |dir|
          # OPTIMIZATION: Skip mkdir_p if directory already exists.
          # During warm-cache runs, these directories always exist.
          unless dir.directory?
            SharedHelpers.filesystem_access(dir) do
              FileUtils.mkdir_p(dir)
            end
          end
        end
      end

      def fetch(remote_path, path, etag_path)
        if already_fetched?(remote_path)
          Bundler::CompactIndexClient.debug { "already fetched #{remote_path}" }
          IOTrace.note(:http, "compact_index already fetched: #{remote_path}")
        else
          Bundler::CompactIndexClient.debug { "fetching #{remote_path}" }
          IOTrace.trace(:http, "compact_index fetch: #{remote_path}") do
            @updater&.update(remote_path, path, etag_path)
          end
        end

        read(path)
      end

      def already_fetched?(remote_path)
        @mutex.synchronize { !@endpoints.add?(remote_path) }
      end

      def read(path)
        return unless path.file?
        IOTrace.trace(:file_read, "compact_index read: #{path}") do
          SharedHelpers.filesystem_access(path, :read, &:read)
        end
      end
    end
  end
end
