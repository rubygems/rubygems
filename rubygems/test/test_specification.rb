require 'test/unit'
require 'rubygems'
Gem::manage_gems

class TestSpecification < Test::Unit::TestCase
  def setup
    @gem_spec = Gem::Specification.new do |s|
      s.version = "1.0.0"
      s.name = "boo"
      s.platform = Gem::Platform::RUBY
      s.date = Time.now
      s.summary = "Hello"
      s.require_paths = ["."]
    end
    @gem_spec.mark_version 
  end

  def test_empty_specification_is_invalid
    spec = Gem::Specification.new
    assert_raises(Gem::InvalidSpecificationException) {
      spec.validate
    }
  end

  def test_empty_non_nil_require_paths_is_invalid
    @gem_spec.require_paths = []
    assert_raises(Gem::InvalidSpecificationException) {
      @gem_spec.validate
    }
  end

  def test_spec_with_all_required_attributes_validates
    assert_nothing_raised {
      @gem_spec.validate
    }
  end

  def test_rdoc_files_included
    @gem_spec.files = %w(a b c d)
    @gem_spec.extra_rdoc_files = %w(x y z)
    @gem_spec.normalize
    assert @gem_spec.files.include? 'x'
  end

  def test_duplicate_files_removed
    @gem_spec.files = %w(a b c d b)
    @gem_spec.extra_rdoc_files = %w(x y z x)
    @gem_spec.normalize
    assert_equal 1, @gem_spec.files.select{|n| n=='b'}.size
    assert_equal 1, @gem_spec.extra_rdoc_files.select{|n| n=='x'}.size
  end

  def test_invalid_version_in_gem_spec_makes_spec_invalid
    @gem_spec.rubygems_version = "3"
    assert_raises(Gem::InvalidSpecificationException) { @gem_spec.validate }
  end
end
