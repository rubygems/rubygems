require 'rubygems/test_case'
require 'rubygems'
require 'rubygems/fs'
require 'fileutils'

class TestGemFS < Gem::TestCase

  def test_fs_constructor
    #
    # These tests aren't probably necessary, but they help me sleep.
    #
    fs = Gem::FS.new(@tempdir)

    assert_kind_of Gem::FS, fs, "kind of Gem::FS"
    assert_equal fs.to_s, @tempdir.to_s, "string representations are the same"
    refute_equal fs.object_id, @tempdir.object_id, "objects are different"
  end

  def test_fs_ensure_gem_subdirectories
    tmpdir = create_tmpdir
   
    assert tmpdir, "#{tmpdir} is non-nil"
    refute_equal "", tmpdir, "not about to throttle your system"

    path = Gem::Path.new(tmpdir)

    Gem::FS::DIRECTORIES.each do |dir|
      assert !path.add(dir).exist?, "path #{dir} does not exist"
    end

    fs = Gem::FS.new(tmpdir)
    fs.ensure_gem_subdirectories

    Gem::FS::DIRECTORIES.each do |dir|
      assert path.add(dir).exist?, "path #{dir} exists"
    end

    FileUtils.rm_r fs
  end

  def test_fs_statics
    fs = Gem::FS.new(@tempdir)

    %w[bin cache specifications gems doc source_cache].each do |dir|
      assert_kind_of Gem::Path, fs.send(dir), 'converts to a Gem::Path'
      assert_equal fs.add(dir), fs.send(dir), 'actually does the same thing as add'
      assert_equal File.join(fs, dir), fs.send(dir), 'uses File.join'
    end
  end

  def test_fs_inheritance
    fs = Gem::FS.new(@tempdir)
    assert_kind_of Gem::Path, fs, "Gem::FS objects are also Gem::Path objects"
p Gem::Path.instance_methods - Gem::FS.instance_methods

p Gem::FS.instance_methods - Gem::Path.instance_methods

  end
end
