#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'test/gemutilities'
require 'rubygems/indexer'

class TestGemIndexer < RubyGemTestCase

  def setup
    super

    util_make_gems

    gems = File.join(@tempdir, 'gems')
    FileUtils.mkdir_p gems
    cache_gems = File.join @gemhome, 'cache', '*.gem'
    FileUtils.mv Dir[cache_gems], gems

    @indexer = Gem::Indexer.new @tempdir
  end

  def test_initialize
    assert_equal @tempdir, @indexer.dest_directory
    assert_equal File.join(Dir.tmpdir, "gem_generate_index_#{$$}"),
                 @indexer.directory
  end

  def test_generate_index
    use_ui @ui do
      @indexer.generate_index
    end

    assert File.exist?(File.join(@tempdir, 'yaml'))
    assert File.exist?(File.join(@tempdir, 'yaml.Z'))
    assert File.exist?(File.join(@tempdir, "Marshal.#{@marshal_version}"))
    assert File.exist?(File.join(@tempdir, "Marshal.#{@marshal_version}.Z"))

    quickdir = File.join(@tempdir, 'quick')
    assert File.directory?(quickdir)
    assert File.exist?(File.join(quickdir, "index"))
    assert File.exist?(File.join(quickdir, "index.rz"))
    assert File.exist?(File.join(quickdir, "#{@a0_0_1.full_name}.gemspec.rz"))
    assert File.exist?(File.join(quickdir, "#{@a0_0_1.full_name}.gemspec.marshal.#{@marshal_version}.rz"))
    assert File.exist?(File.join(quickdir, "#{@a0_0_2.full_name}.gemspec.rz"))
    assert File.exist?(File.join(quickdir, "#{@a0_0_2.full_name}.gemspec.marshal.#{@marshal_version}.rz"))
    assert File.exist?(File.join(quickdir, "#{@b0_0_2.full_name}.gemspec.rz"))
    assert File.exist?(File.join(quickdir, "#{@c1_2.full_name}.gemspec.rz"))
    assert !File.exist?(File.join(quickdir, "#{@c1_2.full_name}.gemspec"))
    assert !File.exist?(File.join(quickdir, "#{@c1_2.full_name}.gemspec.marshal.#{@marshal_version}"))
  end

  def test_generate_index_ui
    use_ui @ui do
      @indexer.generate_index
    end

    expected = <<-EOF
Generating index for 4 gems in #{@tempdir}
....
complete
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_generate_index_contents
    use_ui @ui do
      @indexer.generate_index
    end
    yaml_path = File.join(@tempdir, 'yaml')
    dump_path = File.join(@tempdir, "Marshal.#{@marshal_version}")

    yaml_index = YAML.load_file(yaml_path)
    dump_index = Marshal.load(File.read(dump_path))

    assert_equal yaml_index, dump_index,
                 "expected YAML and Marshal to produce identical results"
  end

end

