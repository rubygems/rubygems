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

    assert_equal "~", path.to_s, 'Gem::Path does not expands paths'

    path = Gem::Path.new(Pathname.new("~"))

    assert_equal "~", path.to_s, 'Gem::Path properly handles Pathname'
  end

  def test_readable?
    path = Gem::Path.new(@tempdir)

    assert File.readable?(@tempdir), "File thinks #{@tempdir} is readable"
    assert path.readable?, "Gem::Path thinks #{@tempdir} is readable"

    skip "Windows doesn't support chmod" if win_platform?

    begin
      FileUtils.chmod 0000, @tempdir
  
      assert !File.readable?(@tempdir), "File no longer thinks #{@tempdir} is readable"
      assert !path.readable?, "Gem::Path no longer thinks #{@tempdir} is readable"
    ensure  
      FileUtils.chmod 0750, @tempdir
    end
  end

  def test_writable?
    path = Gem::Path.new(@tempdir)

    assert File.writable?(@tempdir), "File thinks #{@tempdir} is writable"
    assert path.writable?, "Gem::Path thinks #{@tempdir} is writable"
    
    skip "Windows doesn't support chmod" if win_platform?

    begin
      FileUtils.chmod 0000, @tempdir

      assert !File.writable?(@tempdir), 
        "File no longer thinks #{@tempdir} is writable"

      assert !path.writable?, 
        "Gem::Path no longer thinks #{@tempdir} is writable"
    ensure
      FileUtils.chmod 0750, @tempdir
    end
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
      path.subtract('foo').expand_path, 
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

    FileUtils.rm_r path
  end

  def test_stat
    path = Gem::Path.new(@tempdir, 'file')

    File.open(path, 'w').close

    assert_kind_of File::Stat, path.stat, 
      "stat returns a File::Stat object"

    FileUtils.rm path
  end

  def test_directory?
    path = Gem::Path.new(@tempdir, 'dir')

    FileUtils.mkdir_p path

    assert path.directory?, "path is a directory"

    file = Gem::Path.new(@tempdir, 'file')

    File.open(file, 'w').close

    assert !file.directory?, "file is not a directory"

    FileUtils.rm_r path
    FileUtils.rm file
  end

  def test_string_handling
    path = Gem::Path.new(@tempdir)

    assert_kind_of String, path.to_s, "to_s yields a string"
    assert_kind_of String, path.to_str, "to_str yields a string"

    refute_equal path.instance_variable_get(:@path).object_id, 
      path.to_s.object_id, 
      "objects are not the same"

    assert_respond_to path, :=~, "responds to =~"

    assert path =~ /#{Regexp.escape @tempdir}/

    assert_equal path.to_s.hash, path.hash, "hash and hash of string are equivalent"
    assert_equal 0, path <=> path, "Comparable works"
  end

  def test_expand_path
    assert_equal File.expand_path("~"), 
      Gem::Path.new("~").expand_path, 
      "#expand_path works."
  end

  def test_plus
    assert_equal "/tmp/foo.gem", 
      Gem::Path.new("/tmp/foo") + ".gem", 
      "#+ works."
  end

  def test_split
    assert_equal ["/", "tmp", "foo"], 
      Gem::Path.new("/tmp/foo").split,
      "paths get split into individual components"

    assert_equal ["/", "tmp", "foo"],
      Gem::Path.new("/tmp//foo").split,
      "paths get split into individual components, part 2"
    
    assert_equal [".", "tmp", "foo"],
      Gem::Path.new("tmp/foo").split,
      "paths get split into individual components, part 3"
  end

  def test_relative
    assert_equal Gem::Path.new("foo"),
      Gem::Path.new("/tmp/bar/foo").relative("/tmp/bar"),
      "relative takes a string path and gets the right value"

    assert_equal Gem::Path.new("foo"),
      Gem::Path.new("/tmp/bar/foo").relative(Gem::Path.new("/tmp/bar")),
      "relative takes a Gem::Path and gets the right value"

    assert_equal Gem::Path.new("foo"),
      Gem::Path.new("tmp/bar/foo").relative("tmp/bar"),
      "relative paths should work with #relative"
  end

  def test_basename
    assert_equal Gem::Path.new("foo"),
      Gem::Path.new("/tmp/bar/foo").basename,
      "basename works"

    assert_equal Gem::Path.new("foo"),
      Gem::Path.new("/tmp/bar/foo.gem").basename('.gem'),
      "basename works with an extension argument"
  end

  def test_sub
    assert_equal "/tmp/", 
      Gem::Path.new("/tmp/foo").sub(/foo/, ''),
      "basic #sub works"

    assert_equal "/tmp/",
      Gem::Path.new("/tmp/foo").sub(/foo/) { '' },
      "block sub works"
  end

  def test_read

    File.open(@gemhome.add('test_read'), 'w') { |f| f.print "hello" }

    assert_equal "hello", 
      @gemhome.add('test_read').read, 
      "#read works"

    assert_equal "he",
      @gemhome.add('test_read').read(2),
      "#read works with a numeric argument"

    FileUtils.rm @gemhome.add('test_read')
  end

  def test_file?
    FileUtils.mkdir(@gemhome.add('test_dir'))
    File.open(@gemhome.add('test_file'), 'w').close

    assert @gemhome.add('test_file').file?, "test_file is a file"
    refute @gemhome.add('test_dir').file?, "test_dir is not a file"

    FileUtils.rm_r @gemhome.add('test_dir')
    FileUtils.rm @gemhome.add('test_file')
  end
end
