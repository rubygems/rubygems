#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require File.join(File.expand_path(File.dirname(__FILE__)), 'gemutilities')

require 'rubygems/indexer'

unless ''.respond_to? :to_xs then
  warn "Gem::Indexer tests are being skipped.  Install builder gem."
end

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

    assert File.exist?(File.join(@tempdir, 'yaml')), 'yaml'
    assert File.exist?(File.join(@tempdir, 'yaml.Z')), 'yaml.Z'
    assert File.exist?(File.join(@tempdir, "Marshal.#{@marshal_version}"))
    assert File.exist?(File.join(@tempdir, "Marshal.#{@marshal_version}.Z"))

    quickdir = File.join @tempdir, 'quick'
    marshal_quickdir = File.join quickdir, "Marshal.#{@marshal_version}"

    assert File.directory?(quickdir)
    assert File.directory?(marshal_quickdir)

    assert_indexed quickdir, "index"
    assert_indexed quickdir, "index.rz"

    assert_indexed quickdir, "latest_index"
    assert_indexed quickdir, "latest_index.rz"

    assert_no_match %r|a-1|, File.read(File.join(quickdir, 'latest_index'))

    assert_indexed quickdir, "#{@a1.full_name}.gemspec.rz"
    assert_indexed quickdir, "#{@a2.full_name}.gemspec.rz"
    assert_indexed quickdir, "#{@b2.full_name}.gemspec.rz"
    assert_indexed quickdir, "#{@c1_2.full_name}.gemspec.rz"

    assert_indexed quickdir, "#{@pl1.original_name}.gemspec.rz"
    deny_indexed quickdir, "#{@pl1.full_name}.gemspec.rz"

    assert_indexed marshal_quickdir, "#{@a1.full_name}.gemspec.rz"
    assert_indexed marshal_quickdir, "#{@a2.full_name}.gemspec.rz"

    deny_indexed quickdir, "#{@c1_2.full_name}.gemspec"
    deny_indexed marshal_quickdir, "#{@c1_2.full_name}.gemspec"
  end

  def test_generate_index_ui
    use_ui @ui do
      @indexer.generate_index
    end

    expected = <<-EOF
Loading 6 gems from #{@tempdir}
......
Loaded all gems
Generating quick index gemspecs for 6 gems
......
Complete
Generating quick index
Generating latest index
Generating Marshal master index
Generating YAML master index for 6 gems (this may take a while)
......
Complete
Compressing indicies
    EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end

  def test_generate_index_contents
    use_ui @ui do
      @indexer.generate_index
    end

    yaml_path = File.join @tempdir, 'yaml'
    dump_path = File.join @tempdir, "Marshal.#{@marshal_version}"

    yaml_index = YAML.load_file yaml_path
    dump_index = Marshal.load Gem.read_binary(dump_path)

    dump_index.each do |_,gem|
      gem.send :remove_instance_variable, :@loaded
    end

    assert_equal yaml_index, dump_index,
                 "expected YAML and Marshal to produce identical results"
  end

  def assert_indexed(dir, name)
    file = File.join dir, name
    assert File.exist?(file), "#{file} does not exist"
  end

  def deny_indexed(dir, name)
    file = File.join dir, name
    assert !File.exist?(file), "#{file} exists"
  end

end if ''.respond_to? :to_xs

