require 'test/unit'
require 'rubygems'
Gem::manage_gems

# Load a file relative to the 'test/data' directory.  Return its contents as a String.
def load_data(relpath)
  this_dir = File.dirname(__FILE__)       # The 'test' directory.
  path = File.join(this_dir, 'data', relpath)
  return File.read(path)
end

class TestDefaultSpecification < Test::Unit::TestCase
  def test_defaults
    spec = Gem::Specification.new do |s|
      s.name = "blah"
      s.version = "1.3.5"
    end
    assert_equal "blah", spec.name
    assert_equal "1.3.5", spec.version.to_s
    assert_equal Gem::Platform::RUBY, spec.platform
    assert_equal nil, spec.summary
    assert_equal [], spec.files
  end
end

class TestSimpleSpecification < Test::Unit::TestCase
  def setup
    @spec = Gem::Specification.new do |s|
      s.version = "1.0.0"
      s.name = "boo"
      s.platform = Gem::Platform::RUBY
      s.date = Time.now
      s.summary = "Hello"
      s.require_paths = ["."]
    end
    @spec.mark_version 
  end

  def test_empty_specification_is_invalid
    spec = Gem::Specification.new
    assert_raises(Gem::InvalidSpecificationException) {
      spec.validate
    }
  end

  def test_empty_non_nil_require_paths_is_invalid
    @spec.require_paths = []
    assert_raises(Gem::InvalidSpecificationException) {
      @spec.validate
    }
  end

  def test_spec_with_all_required_attributes_validates
    assert_nothing_raised {
      @spec.validate
    }
  end

  def test_rdoc_files_included
    @spec.files = %w(a b c d)
    @spec.extra_rdoc_files = %w(x y z)
    @spec.normalize
    assert @spec.files.include?('x')
  end

  def test_duplicate_files_removed
    @spec.files = %w(a b c d b)
    @spec.extra_rdoc_files = %w(x y z x)
    @spec.normalize
    assert_equal 1, @spec.files.select{|n| n=='b'}.size
    assert_equal 1, @spec.extra_rdoc_files.select{|n| n=='x'}.size
  end

  def test_invalid_version_in_gem_spec_makes_spec_invalid
    @spec.rubygems_version = "3"
    assert_raises(Gem::InvalidSpecificationException) { @spec.validate }
  end

  def test_singular_attributes
    @spec.require_path = 'mylib'
    @spec.test_file = 'test/suite.rb'
    @spec.executable = 'bin/app'
    assert_equal ['mylib'], @spec.require_paths
    assert_equal ['test/suite.rb'], @spec.test_files
    assert_equal ['bin/app'], @spec.executables
  end

  def test_add_bindir_to_list_of_files
    @spec.bindir = 'apps'
    @spec.executable = 'app'
    assert_equal ['apps/app'], @spec.files
  end

  def test_no_bindir_in_list_of_files
    @spec.bindir = nil
    @spec.executable = 'bin/app'
    assert_equal ['bin/app'], @spec.files
  end

  def test_deprecated_attributes
    @spec.test_suite_file = 'test/suite.rb'
    assert_equal ['test/suite.rb'], @spec.test_files
    # XXX: what about the warning?
  end

  def test_attribute_names
    expected_value = %w{
      rubygems_version specification_version name version date summary
      require_paths authors email homepage rubyforge_project description
      autorequire default_executable bindir has_rdoc required_ruby_version
      platform files test_files rdoc_options extra_rdoc_files
      executables extensions requirements dependencies
    }.sort
    actual_value = Gem::Specification.attribute_names.map { |a| a.to_s }.sort
    assert_equal expected_value, actual_value
  end

  # TODO: test all the methods in the "convenience class methods" section of specification.rb

  def test_defaults
    # @spec is pretty plain, so we'll test some of the default values.
    assert_equal [], @spec.test_files
    assert_equal [], @spec.rdoc_options
    assert_equal [], @spec.extra_rdoc_files
    assert_equal [], @spec.executables
    assert_equal [], @spec.extensions
    assert_equal [], @spec.requirements
    assert_equal [], @spec.dependencies
    assert_equal 'bin', @spec.bindir
    assert_equal false, @spec.has_rdoc
    assert_equal false, @spec.has_rdoc?
    assert_equal '> 0.0.0', @spec.required_ruby_version.to_s
  end

  def test_directly_setting_dependencies_doesnt_work
    assert_raises(NoMethodError) do
      @spec.dependencies = [1,2,3]
    end
  end

  def test_equality
    same_spec = @spec.dup
    assert_equal @spec, same_spec
  end

  def test_to_yaml_and_back
    yaml_str = @spec.to_yaml
    same_spec = YAML.load(yaml_str)
    assert_equal @spec, same_spec
  end

  def test_to_ruby_and_back
    ruby_code = @spec.to_ruby
    same_spec = eval ruby_code
    assert_equal @spec, same_spec
  end
end  # class TestSimpleSpecification


class TestComplexSpecification < Test::Unit::TestCase

  def setup
    @spec = Gem::Specification.new do |s|
      s.name = "rfoo"
      s.version = "0.1"
      # Omit 'platform' and test for default.
      # Omit 'date' and test for default.
      s.summary = <<-EOF
        Ruby/Foo is an example RubyGem used for
        unit testing.
      EOF
      # Omit 'require_paths' and test for default.
      s.author = "The RubyGems Team"
      s.description = s.summary
      s.executable = 'foo1'          # We'll test default_executable.
      s.has_rdoc = 'true'            # We'll test has_rdoc?
      s.test_file = 'test/suite.rb'  # We'll test has_unit_tests?
      s.extensions << 'ext/rfoo/extconf.rb'
      s.requirements << 'A working computer'
      s.add_dependency('rake', '> 0.4')
      s.add_dependency('jabber4r')
      s.add_dependency('pqa', '> 0.4', '<= 0.6')
    end
    @spec.mark_version 
  end

  def test_basics
    @spec.normalize
    summary_value = "Ruby/Foo is an example RubyGem used for unit testing."
    assert_equal 'rfoo',                  @spec.name
    assert_equal '0.1',                   @spec.version.to_s
    assert_equal Gem::Platform::RUBY,     @spec.platform
    assert_equal Date.today,              @spec.date
    assert_equal summary_value,           @spec.summary
    assert_equal summary_value,           @spec.description
    assert_equal "The RubyGems Team",     @spec.author
    assert_equal ['foo1'],                @spec.executables
    assert_equal 'foo1',                  @spec.default_executable
    assert_equal true,                    @spec.has_rdoc?
    assert_equal ['test/suite.rb'],       @spec.test_files
    assert_equal ['ext/rfoo/extconf.rb'], @spec.extensions
    assert_equal ['A working computer'],  @spec.requirements
  end

  def test_dependencies
    deps = @spec.dependencies.map { |d| d.to_s }
    assert_equal 3, deps.size
    assert deps.include?('rake (> 0.4)')
    assert deps.include?('jabber4r (> 0.0.0)')
    assert deps.include?('pqa (> 0.4, <= 0.6)')
  end

  def test_equality
    same_spec = @spec.dup
    assert_equal @spec, same_spec
  end

  def xtest_to_yaml_and_back
    yaml_str = @spec.to_yaml
    same_spec = YAML.load(yaml_str)
    assert_equal @spec, same_spec
  end

  def test_to_ruby_and_back
    ruby_code = @spec.to_ruby
    same_spec = eval ruby_code
    assert_equal @spec, same_spec
  end

  # Test different mechanisms for setting the gem's date: String, Time, and
  # Date.  It should always come out as a Date.
  def test_date_settings
    @spec.date = '2003-09-17'
    assert_equal Date.new(2003, 9, 17), @spec.date
    @spec.date = Time.local(2003, 9, 17)
    assert_equal Date.new(2003, 9, 17), @spec.date
    @spec.date = Date.new(2003, 9, 17)
    assert_equal Date.new(2003, 9, 17), @spec.date
  end
end  # class TestComplexSpecification


class TestLegacyRubySpecification < Test::Unit::TestCase
  def setup
    @ruby_spec = load_data('legacy/keyedlist-0.4.0.ruby')
  end

  def test_eval
    s = gemspec = eval(@ruby_spec)
    assert_equal 'keyedlist', s.name
    assert_equal '0.4.0', s.version.to_s
    assert_equal true, s.has_rdoc?
    assert_equal Date.today, s.date
    assert s.required_ruby_version.satisfied_by?(Gem::Version.new('0.0.1'))
    assert_equal false, s.has_unit_tests?
  end

  def test_to_ruby_and_back
    gemspec1 = eval(@ruby_spec)
    ruby_code = gemspec1.to_ruby
    gemspec2 = eval(ruby_code)
    assert_equal gemspec1, gemspec2
  end
end  # class TestLegacyRubySpecification


class TestLegacyYamlSpecification < Test::Unit::TestCase
  def setup
    @yaml_spec = load_data('legacy/keyedlist-0.4.0.yaml')
  end

  def test_load
    s = gemspec = YAML.load(@yaml_spec)
    assert_equal 'keyedlist', s.name
    assert_equal '0.4.0', s.version.to_s
    assert_equal true, s.has_rdoc?
    #assert_equal Date.today, s.date
    #assert s.required_ruby_version.satisfied_by?(Gem::Version.new('0.0.1'))
    assert_equal false, s.has_unit_tests?
  end

end  # class TestLegacyYamlSpecification
