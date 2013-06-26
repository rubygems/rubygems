require 'rubygems/test_case'
require 'rubygems/progressive_index'

class TestGemProgressiveIndex < Gem::TestCase
  def setup
    super

    util_clear_gems
    util_make_gems

    @d2 = quick_spec 'd', '2.0'
    util_build_gem @d2

    @d3 = quick_spec 'd', '3.0'
    util_build_gem @d3

    @e1 = quick_spec 'e', '1.0' do |s|
      s.add_dependency "d", "~> 3.0"
    end

    util_build_gem @e1
    
    @d4p = quick_spec 'd', '4.0' do |s|
      s.platform = "java"
    end

    util_build_gem @d4p
  end

  def test_one_spec
    gp = Gem::ProgressiveIndex.new([@d2])

    assert_equal "d 2.0\n", gp.output
  end

  def test_many_specs
    gp = Gem::ProgressiveIndex.new([@d2, @d3, @e1])

    assert_equal "d 2.0\nd 3.0\ne 1.0\n", gp.output
  end

  def test_specs_are_not_sorted
    gp = Gem::ProgressiveIndex.new([@e1, @d3, @d2])

    assert_equal "e 1.0\nd 3.0\nd 2.0\n", gp.output
  end

  def test_parses_format_into_nametuples
    gp = Gem::ProgressiveIndex.new
    nt = gp.parse "e 1.0\nd 3.0\nd 2.0\n"

    assert_equal ["e", "1.0", "ruby"], nt[0].to_a
    assert_equal ["d", "3.0", "ruby"], nt[1].to_a
    assert_equal ["d", "2.0", "ruby"], nt[2].to_a
  end

  def test_handles_platforms_on_output
    gp = Gem::ProgressiveIndex.new([@d4p])
    assert_equal "d 4.0 java\n", gp.output
  end

  def test_handles_platform_on_parse
    gp = Gem::ProgressiveIndex.new
    nt = gp.parse "d 4.0 java\n"

    assert_equal ["d", "4.0", "java"], nt[0].to_a
  end

  def test_handles_metadata_pairs_on_parse
    gp = Gem::ProgressiveIndex.new
    nt = gp.parse "d 4.0 java deps:^e|1.0;extra:foo\n"

    assert_equal Gem::Dependency.new("e", "= 1.0"), nt[0].metadata['deps']
    assert_equal "foo", nt[0].metadata['extra']
  end

  def test_handles_metadata_pairs_on_parse_with_spaces
    gp = Gem::ProgressiveIndex.new
    nt = gp.parse "d 4.0 java deps:^e|~> 1.0;extra:foo\n"

    assert_equal Gem::Dependency.new("e", "~> 1.0"), nt[0].metadata['deps']
    assert_equal "foo", nt[0].metadata['extra']
  end

  def test_handles_metadata_values_as_lists
    gp = Gem::ProgressiveIndex.new
    nt = gp.parse "d 4.0 java deps:^e|1.0,^f|>3\n"

    ex = [Gem::Dependency.new("e", "= 1.0"), Gem::Dependency.new("f", "> 3")]
    assert_equal ex, nt[0].metadata['deps']
  end

  def test_handles_remote_includes_on_output
    gp = Gem::ProgressiveIndex.new
    gp.remote_includes << "/blah/more.pindex"

    assert_equal "@/blah/more.pindex\n", gp.output
  end

  def test_handles_remote_includes_on_parse
    gp = Gem::ProgressiveIndex.new
    nt = gp.parse "@/blah/more.pindex\n"

    assert nt.empty?
    assert_equal ["/blah/more.pindex"], gp.remote_includes
  end

  def test_handles_lists_of_nametuples_for_output
    nt = Gem::NameTuple.new "e", "1.0"
    gp = Gem::ProgressiveIndex.new [nt]

    assert_equal "e 1.0\n", gp.output
  end

  def test_outputs_dependencies
    gp = Gem::ProgressiveIndex.new [@e1], :include_deps => true

    assert_equal "e 1.0 runtime_deps=^d|~> 3.0\n", gp.output
  end
end
