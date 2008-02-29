#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require File.join(File.expand_path(File.dirname(__FILE__)),
                  'gem_package_tar_test_case')
require 'rubygems/package/tar_reader'

class TestGemPackageTarReader < TarTestCase

  def test_eof_works
    str = tar_file_header("bar", "baz", 0644, 0)

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        data = entry.read
        assert_equal(nil, data)
        assert_equal(nil, entry.read(10))
        assert_equal(nil, entry.read)
        assert_equal(nil, entry.getc)
        assert_equal(true, entry.eof?)
      end
    end

    str = tar_dir_header("foo", "bar", 012345)

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        data = entry.read
        assert_equal(nil, data)
        assert_equal(nil, entry.read(10))
        assert_equal(nil, entry.read)
        assert_equal(nil, entry.getc)
        assert_equal(true, entry.eof?)
      end
    end

    str = tar_dir_header("foo", "bar", 012345)
    str += tar_file_header("bar", "baz", 0644, 0)
    str += tar_file_header("bar", "baz", 0644, 0)

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        data = entry.read
        assert_equal(nil, data)
        assert_equal(nil, entry.read(10))
        assert_equal(nil, entry.read)
        assert_equal(nil, entry.getc)
        assert_equal(true, entry.eof?)
      end
    end
  end

  def test_multiple_entries
    str = tar_file_header("lib/foo", "", 010644, 10) + "\0" * 512
    str += tar_file_header("bar", "baz", 0644, 0)
    str += tar_dir_header("foo", "bar", 012345)
    str += "\0" * 1024

    names = %w[lib/foo bar foo]
    prefixes = ["", "baz", "bar"]
    modes = [010644, 0644, 012345]
    sizes = [10, 0, 0]
    isdir = [false, false, true]
    isfile = [true, true, false]

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      i = 0
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        assert_equal(names[i], entry.name)
        assert_equal(prefixes[i], entry.prefix)
        assert_equal(sizes[i], entry.size)
        assert_equal(modes[i], entry.mode)
        assert_equal(isdir[i], entry.is_directory?)
        assert_equal(isfile[i], entry.is_file?)
        if prefixes[i] != ""
          assert_equal(File.join(prefixes[i], names[i]),
                       entry.full_name)
        else
          assert_equal(names[i], entry.name)
        end
        i += 1
      end

      assert_equal names.size, i
    end
  end

  def test_read_works
    contents = ('a'..'z').inject(""){|s,x| s << x * 100}
    str = tar_file_header("lib/foo", "", 010644, contents.size) + contents 
    str += "\0" * (512 - (str.size % 512))

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        data = entry.read(3000) # bigger than contents.size
        assert_equal(contents, data)
        assert_equal(true, entry.eof?)
      end
    end

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        data = entry.read(100)
        (entry.size - data.size).times {|i| data << entry.getc.chr }
        assert_equal(contents, data)
        assert_equal(nil, entry.read(10))
        assert_equal(true, entry.eof?)
      end
    end

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        data = entry.read
        assert_equal(contents, data)
        assert_equal(nil, entry.read(10))
        assert_equal(nil, entry.read)
        assert_equal(nil, entry.getc)
        assert_equal(true, entry.eof?)
      end
    end
  end

  def test_rewind_entry_works
    content = ('a'..'z').to_a.join(" ")
    str = tar_file_header("lib/foo", "", 010644, content.size) + content + 
            "\0" * (512 - content.size)
    str << "\0" * 1024

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      is.each_entry do |entry|
        3.times do 
          entry.rewind
          assert_equal(content, entry.read)
          assert_equal(content.size, entry.pos)
        end
      end
    end
  end

  def test_rewind_works
    content = ('a'..'z').to_a.join(" ")

    str = tar_file_header("lib/foo", "", 010644, content.size) + content + 
            "\0" * (512 - content.size)
    str << "\0" * 1024

    Gem::Package::TarReader.new(StringIO.new(str)) do |is|
      3.times do
        is.rewind
        i = 0
        is.each_entry do |entry|
          assert_equal(content, entry.read)
          i += 1
        end
        assert_equal(1, i)
      end
    end
  end

end

