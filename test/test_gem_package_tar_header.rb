#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require File.join(File.expand_path(File.dirname(__FILE__)),
                  'gem_package_tar_test_case')
require 'rubygems/package/tar_header'

class TestGemPackageTarHeader < TarTestCase

  def test_arguments_are_checked
    e = ArgumentError
    gpth = Gem::Package::TarHeader
    assert_raises(e) { gpth.new :name=>"", :size=>"", :mode=>"" }
    assert_raises(e) { gpth.new :name=>"", :size=>"", :prefix=>"" }
    assert_raises(e) { gpth.new :name=>"", :prefix=>"", :mode=>"" }
    assert_raises(e) { gpth.new :prefix=>"", :size=>"", :mode=>"" }
  end

  def test_basic_headers
    header = Gem::Package::TarHeader.new(:name => "bla", :mode => 012345,
                                         :size => 10, :prefix => "").to_s
    assert_headers_equal(tar_file_header("bla", "", 012345, 10), header.to_s)
    header = Gem::Package::TarHeader.new(:name => "bla", :mode => 012345,
                                         :size => 0, :prefix => "",
                                         :typeflag => "5" ).to_s
    assert_headers_equal(tar_dir_header("bla", "", 012345), header)
  end

  def test_long_name_works
    header = Gem::Package::TarHeader.new(:name => "a" * 100, :mode => 012345, 
                                         :size => 10, :prefix => "").to_s
    assert_headers_equal(tar_file_header("a" * 100, "", 012345, 10), header)

    header = Gem::Package::TarHeader.new(:name => "a" * 100, :mode => 012345,
                                         :size => 10, :prefix => "bb" * 60).to_s
    assert_headers_equal(tar_file_header("a" * 100, "bb" * 60, 012345, 10),
                         header)
  end

  def test_new_from_stream
    header = tar_file_header("a" * 100, "", 012345, 10)
    h = nil
    header = StringIO.new header
    assert_nothing_raised{ h = Gem::Package::TarHeader.new_from_stream header }
    assert_equal("a" * 100, h.name)
    assert_equal(012345, h.mode)
    assert_equal(10, h.size)
    assert_equal("", h.prefix)
    assert_equal("ustar", h.magic)
  end

end


