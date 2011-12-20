#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

# TODO: Merge with Gem::Builder as Gem::GemFile or something to read and write

require 'rubygems/package'

##
# Gem::Format can read a .gem file

class Gem::Format

  attr_accessor :spec
  attr_accessor :file_entries
  attr_accessor :gem_path

  ##
  # Constructs a Format representing the gem's data which came from +gem_path+

  def initialize(gem_path)
    @gem_path = gem_path
  end

  ##
  # Reads the gem +file_path+ using +security_policy+ and returns a Format
  # representing the data in the gem
  #--
  # TODO this method name is terrible, use ::read

  def self.from_file_by_path(file_path, security_policy = nil)
    unless File.file?(file_path)
      raise Gem::Exception, "Cannot load gem at [#{file_path}] in #{Dir.pwd}"
    end

    start = File.read file_path, 20

    if start.nil? or start.length < 20 then
      nil
    elsif start.include?("MD5SUM =") # old version gems
      require 'rubygems/old_format'

      Gem::OldFormat.from_file_by_path file_path
    else
      # TODO move to an instance method
      begin
        open file_path, Gem.binary_mode do |io|
          from_io io, file_path, security_policy
        end
      rescue Gem::Package::TarInvalidError => e
        message = "corrupt gem (#{e.class}: #{e.message})"
        raise Gem::Package::FormatError.new(message, file_path)
      end
    end
  end

  ##
  # Reads a gem from +io+ at +gem_path+ using +security_policy+ and returns a
  # Format representing the data from the gem

  def self.from_io(io, gem_path="(io)", security_policy = nil)
    format = new gem_path

    # TODO move to an instance method
    Gem::Package.open io, 'r', security_policy do |pkg|
      format.spec = pkg.metadata
      format.file_entries = []

      pkg.each do |entry|
        size = entry.header.size
        mode = entry.header.mode

        format.file_entries << [{
            "size" => size, "mode" => mode, "path" => entry.full_name,
          },
          entry.read # TODO does entry handle this so we can delete it? or seek instead?
        ]
      end
    end

    format
  end

end

