require 'rubygems/test_case'
require 'rubygems'
require 'rubygems/fs'
require 'fileutils'
require 'pathname'

class TestGemPath < Gem::TestCase
  def test_constructor
    #
    # These tests aren't probably necessary, but they help me sleep.
    #
    path = Gem::Path.new('/tmp/test/path')

    assert_kind_of Gem::Path, path, 'is a Gem::Path object'
    assert_equal '/tmp/test/path', path.to_s, 'string representations are the same'
    refute_equal Gem::Path.new(path).object_id, path.object_id, 'newly composed paths are not the same object'

    path = Gem::Path.new('/tmp', 'test', 'path')

    assert_equal '/tmp/test/path', path.to_s, 'Gem::Path joins arguments'

    path = Gem::Path.new("~")

    refute_equal "~", path.to_s, 'Gem::Path expands paths'

    path = Gem::Path.new(Pathname.new("~"))

    refute_equal "~", path.to_s, 'Gem::Path properly handles Pathname'
  end

  def test_readable?
    path = Gem::Path.new(@tempdir)

    assert File.readable?(@tempdir), "File thinks #{@tempdir} is readable"
    assert path.readable?, "Gem::Path thinks #{@tempdir} is readable"

    FileUtils.chmod 0000, @tempdir

    assert !File.readable?(@tempdir), "File no longer thinks #{@tempdir} is readable"
    assert !path.readable?, "Gem::Path no longer thinks #{@tempdir} is readable"

    FileUtils.chmod 0750, @tempdir
  end

  def test_writable?
    path = Gem::Path.new(@tempdir)

    assert File.writable?(@tempdir), "File thinks #{@tempdir} is writable"
    assert path.writable?, "Gem::Path thinks #{@tempdir} is writable"
    
    FileUtils.chmod 0000, @tempdir

    assert !File.writable?(@tempdir), 
      "File no longer thinks #{@tempdir} is writable"

    assert !path.writable?, 
      "Gem::Path no longer thinks #{@tempdir} is writable"
    
    FileUtils.chmod 0750, @tempdir
  end

  def test_add
    path = Gem::Path.new(@tempdir)

    assert_equal File.join(@tempdir, 'foo'), path.add('foo'), 
      'add calls File.join behind the scenes'

    assert_kind_of Gem::Path, path.add('foo'), 
      'returns a Gem::Path object'

    refute_equal path.add('foo').object_id, path.object_id, 
      'objects are not the same' 

    assert_equal path.add('foo'), path / 'foo', 
      '/ works like add'
  end

  def test_subtract
    path = Gem::Path.new(@tempdir, 'foo')

    assert_equal File.expand_path(path.to_s.sub('foo', '')), 
      path.subtract('foo'), 
      'works like #sub'

    assert_kind_of Gem::Path, path.subtract('foo'), 
      'yields another Gem::Path'

    refute_equal path.subtract('foo').object_id, path.object_id, 
      'objects are not the same'
  end

  def test_size
    File.open(File.join(@tempdir, 'size_test'), 'w') { |f| f.print "hello" }
    File.open(File.join(@tempdir, 'size_test2'), 'w') { |f| }

    path_with_size = Gem::Path.new(@tempdir, 'size_test')
    path_zero_size = Gem::Path.new(@tempdir, 'size_test2')

    assert_equal 5, path_with_size.size, 'size of 5'
    assert_equal 0, path_zero_size.size, 'size of 0'

    FileUtils.rm path_with_size
    FileUtils.rm path_zero_size
  end

  def test_dirname
    path = Gem::Path.new(@tempdir, 'foo')

    assert_kind_of Gem::Path, path.dirname, "returns a Gem::Path"
    assert_equal @tempdir, path.dirname, 
      "the dirname of the path equals the tempdir: #{@tempdir}"
  end

  def test_exist?
    path = Gem::Path.new(@tempdir, 'file')

    assert !File.exist?(path), "the path #{path} doesn't exist"
    assert !path.exist?, "the path #{path} doesn't exist"

    File.open(path, 'w').close

    assert File.exist?(path)
    assert path.exist?, "the path #{path} now exists"

    FileUtils.rm path
  end

  def test_glob
    path = Gem::Path.new(@tempdir, 'glob_test')
    FileUtils.mkdir_p path

    files = %w[file_one file_two not_file_three].map do |x| 
      path.add(x)
    end

    files.each { |f| File.open(f, 'w').close }

    assert_equal %w[file_one file_two].map { |x| path.add(x) }, 
      path.glob("file*").sort,
      "globs work"

    assert_equal %w[file_one file_two not_file_three].map { |x| path.add(x) }, 
      path.glob("*file*").sort, 
      "globs work, part 2"
  end
end
