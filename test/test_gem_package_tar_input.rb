#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require File.join(File.expand_path(File.dirname(__FILE__)),
                  'gem_package_tar_test_case')
require 'rubygems/package/tar_input'

class TestGemPackageTarInput < TarTestCase

  # Sometimes the setgid bit doesn't take.  Don't know if this
  # is a problem on all systems, or just some.  But for now, we
  # will ignore it in the tests.
  SETGID_BIT = 02000

  def setup
    FileUtils.mkdir_p "data__"

    inner_tar = tar_file_header("bla", "", 0612, 10)
    inner_tar += "0123456789" + "\0" * 502
    inner_tar += tar_file_header("foo", "", 0636, 5)
    inner_tar += "01234" + "\0" * 507
    inner_tar += tar_dir_header("__dir__", "", 0600)
    inner_tar += "\0" * 1024
    str = StringIO.new ""

    begin
      os = Zlib::GzipWriter.new str
      os.write inner_tar
    ensure
      os.finish
    end

    str.rewind

    File.open("data__/bla.tar", "wb") do |f|
      f.write tar_file_header("data.tar.gz", "", 0644, str.string.size)
      f.write str.string
      f.write "\0" * ((512 - (str.string.size % 512)) % 512 )
      @spec = Gem::Specification.new do |spec|
        spec.author = "Mauricio :)"
      end
      meta = @spec.to_yaml
      f.write tar_file_header("metadata", "", 0644, meta.size)
      f.write meta + "\0" * (1024 - meta.size) 
      f.write "\0" * 1024
    end

    @file = "data__/bla.tar"
    @entry_names = %w{bla foo __dir__}
    @entry_sizes = [10, 5, 0]
    #FIXME: are these modes system dependent?
    @entry_modes = [0100612, 0100636, 040600]
    @entry_files = %w{data__/bla data__/foo}
    @entry_contents = %w[0123456789 01234]
  end

  def test_each_works
    Gem::Package::TarInput.open(@file) do |is|
      count = 0

      is.each_with_index do |entry, i|
        count = i

        assert_kind_of(Gem::Package::TarReader::Entry, entry)
        assert_equal(@entry_names[i], entry.name)
        assert_equal(@entry_sizes[i], entry.size)
      end

      assert_equal 2, count

      assert_equal @spec, is.metadata
    end
  end

  def test_extract_entry_works
    Gem::Package::TarInput.open(@file) do |is|
      assert_equal @spec, is.metadata
      count = 0

      is.each_with_index do |entry, i|
        count = i
        is.extract_entry "data__", entry
        name = File.join("data__", entry.name)

        if entry.is_directory?
          assert File.dir?(name)
        else
          assert File.file?(name) 
          assert_equal(@entry_sizes[i], File.stat(name).size)
          #FIXME: win32? !!
        end

        unless ::Config::CONFIG["arch"] =~ /msdos|win32/i
          assert_equal(@entry_modes[i],
                       File.stat(name).mode & (~SETGID_BIT))
        end
      end

      assert_equal 2, count
    end

    @entry_files.each_with_index do |x, i|
      assert(File.file?(x))
      assert_equal(@entry_contents[i], File.read_b(x))
    end
  end

end


