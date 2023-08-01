# frozen_string_literal: true

require "time"
require "date"
require "digest"

module Gem::Indexer::CompactIndex
  class VersionsFile
    def initialize(file = nil)
      @path = file || "/versions.list"
    end

    def contents(gems = nil, args = {})
      gems = calculate_info_checksums(gems) if args.delete(:calculate_info_checksums) { false }

      raise ArgumentError, "Unknown options: #{args.keys.join(", ")}" unless args.empty?

      File.read(@path).tap do |out|
        out << gem_lines(gems) if gems
      end
    end

    def updated_at
      created_at_header(@path) || Time.at(0).to_datetime
    end

    def create(gems, ts = Time.now.iso8601)
      gems.sort!

      File.open(@path, "w") do |io|
        io.write "created_at: #{ts}\n---\n"
        io.write gem_lines(gems)
      end
    end

  private

    def gem_lines(gems)
      gems.reduce("".dup) do |lines, gem|
        version_numbers = gem.versions.map(&:number_and_platform).join(",")
        lines << gem.name <<
          " ".freeze << version_numbers <<
          " #{gem.versions.last.info_checksum}\n"
      end
    end

    def calculate_info_checksums(gems)
      gems.each do |gem|
        info_checksum = Digest::MD5.hexdigest(Gem::Indexer::CompactIndex.info(gem[:versions]))
        gem[:versions].last[:info_checksum] = info_checksum
      end
    end

    def created_at_header(path)
      return unless File.exist? path

      File.open(path) do |file|
        file.each_line do |line|
          line.match(/created_at: (.*)\n|---\n/) do |match|
            return match[1] && DateTime.parse(match[1])
          end
        end
      end

      nil
    end
  end
end
