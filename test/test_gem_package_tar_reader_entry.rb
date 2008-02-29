#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require File.join(File.expand_path(File.dirname(__FILE__)),
                  'gem_package_tar_test_case')
require 'rubygems/package/tar_reader/entry'

class TestGemPackageTarReaderEntry < TarTestCase

  def setup
    super

    @contents = ('a'..'z').to_a.join * 100

    @tar = ''
    @tar << tar_file_header("lib/foo", "", 0, @contents.size)
    @tar << @contents
    @tar << "\0" * (512 - (@tar.size % 512))

    @entry = util_entry @tar
  end

  def test_bytes_read
    assert_equal 0, @entry.bytes_read

    @entry.getc

    assert_equal 1, @entry.bytes_read
  end

  def test_close
    @entry.close

    assert @entry.bytes_read

    e = assert_raise IOError do @entry.eof? end
    assert_equal 'closed Gem::Package::TarReader::Entry', e.message

    e = assert_raise IOError do @entry.getc end
    assert_equal 'closed Gem::Package::TarReader::Entry', e.message

    e = assert_raise IOError do @entry.pos end
    assert_equal 'closed Gem::Package::TarReader::Entry', e.message

    e = assert_raise IOError do @entry.read end
    assert_equal 'closed Gem::Package::TarReader::Entry', e.message

    e = assert_raise IOError do @entry.rewind end
    assert_equal 'closed Gem::Package::TarReader::Entry', e.message
  end

  def test_closed_eh
    @entry.close

    assert @entry.closed?
  end

  def test_eof_eh
    @entry.read

    assert @entry.eof?
  end

  def test_full_name
    assert_equal 'lib/foo', @entry.full_name
  end

  def test_getc
    assert_equal ?a, @entry.getc
  end

  def test_is_directory_eh
    assert_equal false, @entry.is_directory?
    assert_equal true, util_dir_entry.is_directory?
  end

  def test_is_file_eh
    assert_equal true, @entry.is_file?
    assert_equal false, util_dir_entry.is_file?
  end

  def test_pos
    assert_equal 0, @entry.pos

    @entry.getc

    assert_equal 1, @entry.pos
  end

  def test_read
    assert_equal @contents, @entry.read
  end

  def test_read_big
    assert_equal @contents, @entry.read(@contents.size * 2)
  end

  def test_read_small
    assert_equal @contents[0...100], @entry.read(100)
  end

  def test_rewind
    char = @entry.getc

    @entry.rewind

    assert_equal 0, @entry.pos

    assert_equal char, @entry.getc
  end

  def util_entry(tar)
    io = StringIO.new tar
    header = Gem::Package::TarHeader.new_from_stream io
    entry = Gem::Package::TarReader::Entry.new header, io
  end

  def util_dir_entry
    util_entry tar_dir_header("foo", "bar", 0)
  end

end

