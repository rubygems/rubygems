# frozen_string_literal: true

#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

class Gem::Ext::ExtConfBuilder < Gem::Ext::Builder
  def self.build(extension, dest_path, results, args=[], lib_dir=nil, extension_dir=Dir.pwd)
    require "fileutils"

    destdir = ENV["DESTDIR"]

    begin
      cmd = ruby << File.basename(extension)
      cmd.push(*args)

      run(cmd, results, class_name, extension_dir) do |s, r|
        mkmf_log = File.join(extension_dir, "mkmf.log")
        if File.exist? mkmf_log
          unless s.success?
            r << "To see why this extension failed to compile, please check" \
              " the mkmf.log which can be found here:\n"
            r << "  " + File.join(dest_path, "mkmf.log") + "\n"
          end
          FileUtils.mv mkmf_log, dest_path
        end
      end

      ENV["DESTDIR"] = nil

      rel_dest_path = get_relative_path(dest_path, extension_dir)
      make rel_dest_path, results, extension_dir

      # TODO: remove in RubyGems 4
      if Gem.install_extension_in_lib && lib_dir
        FileUtils.mkdir_p lib_dir
        entries = Dir.entries(dest_path) - %w[. ..]
        entries = entries.map {|entry| File.join dest_path, entry }
        FileUtils.cp_r entries, lib_dir, remove_destination: true
      end

      make dest_path, results, extension_dir, ["clean"]
    ensure
      ENV["DESTDIR"] = destdir
    end

    results
  end

  def self.get_relative_path(path, base)
    path_parts = get_path_parts(path)
    base_parts = get_path_parts(base)
    # Right pad path_parts to be at least as long as base_parts so we can
    # zip without losing any components from base_parts
    path_parts.fill(nil, path_parts.length...base_parts.length)

    relative_path_parts, relative_base_parts = path_parts.
      zip(base_parts).
      drop_while {|path_part, base_part| path_part == base_part }.
      transpose.
      map(&:compact)

    File.join(relative_base_parts.fill(".."), relative_path_parts)
  end

  def self.get_path_parts(path)
    parts = []

    until File.dirname(path) == path
      dirname, basename = File.split(path)
      path = dirname
      parts << basename
    end

    parts.reverse
  end
end
