#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require File.join(File.expand_path(File.dirname(__FILE__)),
                  'gem_package_tar_test_case')
require 'rubygems/package/tar_output'

class TestGemPackageTarOutput < TarTestCase

  def setup
    super

    @file = File.join @tempdir, 'bla2.tar'
  end

  def test_file_looks_good
    Gem::Package::TarOutput.open @file do |os|
      os.metadata = "bla".to_yaml
    end

    f = File.open @file, "rb"

    Gem::Package::TarReader.new f do |is|
      i = 0
      is.each do |entry|
        case i
        when 0
          assert_equal("data.tar.gz", entry.header.name)
        when 1
          assert_equal("metadata.gz", entry.header.name)
          gzis = Zlib::GzipReader.new entry
          assert_equal("bla".to_yaml, gzis.read)
          gzis.close
        end
        i += 1
      end

      assert_equal 2, i
    end

  ensure
    f.close
  end

end


