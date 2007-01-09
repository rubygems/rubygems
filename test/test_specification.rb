#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

require 'test/unit'
require 'stringio'
require 'test/gemutilities'
require 'rubygems'
Gem::manage_gems

LEGACY_GEM_SPEC_FILE = 'test/data/legacy/keyedlist-0.4.0.ruby'
LEGACY_GEM_YAML_FILE = 'test/data/legacy/keyedlist-0.4.0.yaml'

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
      executables extensions requirements dependencies signing_key cert_chain
      post_install_message
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

  def test_array_attributes
    @spec.files = (1..10)
    assert_equal Array, @spec.files.class
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

class TestSpecification < RubyGemTestCase

  def setup
    super
    @spec = quick_gem "TestSpecification"
  end

  def test_autorequire_array
    name = "AutorequireArray"
    files = %w(a.rb b.rb)
    gem = quick_gem(name) do |s|
      s.files = files.map { |f| File.join("lib", f) }
      s.autorequire = files
    end

    fullname = gem.full_name

    write_file("gems/#{fullname}/lib/a.rb") do |io|
      io.puts "$LOADED_A = true"
    end

    write_file("gems/#{fullname}/lib/b.rb") do |io|
      io.puts "$LOADED_B = true"
    end

    old_loaded = $".dup
    old_verbose = $VERBOSE
    $VERBOSE = nil
    require_gem name
    $VERBOSE = old_verbose
    new_loaded = $".dup

    assert_equal(files, (new_loaded - old_loaded))
    assert(defined? $LOADED_A)
    assert(defined? $LOADED_B)
  end

  def test_autorequire_string
    name = "AutorequireString"
    file = "c.rb"
    gem = quick_gem(name) do |s|
      s.files = File.join("lib", file)
      s.autorequire = file
    end

    fullname = gem.full_name

    write_file("gems/#{fullname}/lib/c.rb") do |io|
      io.puts "$LOADED_C = true"
    end

    old_loaded = $".dup
    old_verbose = $VERBOSE
    $VERBOSE = nil
    require_gem name
    $VERBOSE = old_verbose
    new_loaded = $".dup

    assert_equal(Array(file), (new_loaded - old_loaded))
    assert(defined? $LOADED_C)
  end

  def test_date_equals_date
    @spec.date = Date.new(2003, 9, 17)
    assert_equal Time.local(2003, 9, 17, 0,0,0), @spec.date
  end

  def test_date_equals_string
    @spec.date = '2003-09-17'
    assert_equal Time.local(2003, 9, 17, 0,0,0), @spec.date
  end

  def test_date_equals_time
    @spec.date = Time.local(2003, 9, 17, 0,0,0)
    assert_equal Time.local(2003, 9, 17, 0,0,0), @spec.date
  end

  def test_date_equals_time_local
    # HACK PDT
    @spec.date = Time.local(2003, 9, 17, 19,50,0)
    assert_equal Time.local(2003, 9, 17, 0,0,0), @spec.date
  end

  def test_date_equals_time_utc
    # HACK PDT
    @spec.date = Time.local(2003, 9, 17, 19,50,0)
    assert_equal Time.local(2003, 9, 17, 0,0,0), @spec.date
  end

  def test_default_executable
    @spec.default_executable = nil
    @spec.instance_variable_set :@executables, nil
    assert_equal nil, @spec.default_executable
  end
  
  def test_files_combines_several_accessor_values
    @spec.files = %w(files bin/common)
    @spec.test_files = %w(test_files bin/common)
    @spec.executables = %w(executables common)
    @spec.extra_rdoc_files = %w(extra_rdoc_files bin/common)
    @spec.extensions = %w(extensions bin/common)
    
    assert_equal(
      %w(files test_files bin/executables extra_rdoc_files extensions bin/common).sort,
      @spec.files.sort)
  end

  def test_non_array_stuff_doesnt_goof_up_files
    @spec.files = "F"
    @spec.test_files = "TF"
    @spec.executables = "X"
    @spec.extra_rdoc_files = "ERF"
    @spec.extensions = "E"
    
    assert_equal %w(TF F bin/X ERF E).sort, @spec.files.sort
  end
  
  def test_pathologically_bad_non_array_stuff_doesnt_goof_up_files
    @spec.instance_variable_set "@files", "F"
    @spec.instance_variable_set "@test_files", "TF"
    @spec.instance_variable_set "@extra_rdoc_files", "ERF"
    @spec.instance_variable_set "@extensions", "E"
    
    assert_equal %w(F TF ERF E).sort, @spec.files.sort
    assert_kind_of Integer, @spec.hash
  end
  
  def test_pathologically_bad_exectuables_doesnt_goof_up_hash
    t = Time.now
    @spec.instance_variable_set("@executables", t)
    assert_kind_of Integer, @spec.hash
  end

  def test_to_ruby
    today = Time.now.strftime("%Y-%m-%d")
    ruby = "Gem::Specification.new do |s|
  s.name = %q{TestSpecification}
  s.version = \"0.0.2\"
  s.date = %q{#{today}}
  s.summary = %q{this is a summary}
  s.email = %q{example@example.com}
  s.homepage = %q{http://example.com}
  s.description = %q{This is a test description}
  s.has_rdoc = true
  s.authors = [\"A User\"]
end
"
    assert_equal ruby, @spec.to_ruby
  end

end

class TestSpecificationEquality < RubyGemTestCase

  def test_eql_eh
    g1 = quick_gem 'gem'
    g2 = quick_gem 'gem'

    assert_equal g1, g2
    assert_equal g1.hash, g2.hash
    assert_equal true, g1.eql?(g2)
  end

  def test_equals_is_true_on_same_specification
    s = Gem::Specification.new
    assert s == s
  end

  def test_specs_with_same_attributes_are_equal
    s = Gem::Specification.new do |spec| spec.name = "ONE" end
    t = Gem::Specification.new do |spec| spec.name = "ONE" end
    assert_equal s, t
    assert_equal t, s
  end

  def test_specs_with_same_attributes_have_same_hash_code
    s = Gem::Specification.new do |spec| spec.name = "ONE" end
    t = Gem::Specification.new do |spec| spec.name = "ONE" end
    assert_equal s.hash, t.hash
  end

  def test_specs_with_different_attributes_are_not_equal
    s = Gem::Specification.new do |spec| spec.name = "ONE" end
    t = Gem::Specification.new do |spec| spec.name = "TWO" end
    assert ! (s == t)
    assert ! (t == s)
  end

  def test_specs_with_different_attributes_have_different_hash_codes
    s = Gem::Specification.new do |spec| spec.name = "ONE" end
    t = Gem::Specification.new do |spec| spec.name = "TWO" end
    assert s.hash != t.hash
  end

  def test_equals_is_false_on_non_spec_objects
    s = Gem::Specification.new
    t = Object.new
    assert ! (s == t)
    assert ! (t == s)
  end
  
  def test_proper_behavior_with_nil_default_executable
    a, b, c = (0..2).collect {
      Gem::Specification.new do |s|
        s.name = "abc"
        s.version = "1.2.3"
        s.default_executable = nil
        s.executables = []
      end
    }
    c.default_executable = "xx"
    assert a == b
    assert a != c
    assert c != a
  end
  
  def test_proper_behavior_with_bad_non_array_value_for_extensions
    a, b, c = (0..2).collect {
      Gem::Specification.new do |s|
        s.name = "abc"
        s.version = "1.2.3"
        s.extensions = "bad value"
      end
    }
    c.extensions = []
    assert a == b
    assert a != c
    assert c != a
  end
  
  # The cgikit specification was reported to be causing trouble in at least 
  # one version of RubyGems, so we test explicitly for it.  
  def test_cgikit_specification
    cgikit = Gem::Specification.new do |s|
      s.name = %q{cgikit}
      s.version = "1.1.0"
      s.date = %q{2004-03-13}
      s.summary = %q{CGIKit is a componented-oriented web application } +
      %q{framework like Apple Computers WebObjects.  } +
      %{This framework services Model-View-Controller architecture } +
      %q{programming by components based on a HTML file, a definition } +
      %q{file and a Ruby source.  }
      s.email = %q{info@spice-of-life.net}
      s.homepage = %q{http://www.spice-of-life.net/download/cgikit/}
      s.autorequire = %q{cgikit}
      s.bindir = nil
      s.has_rdoc = nil
      s.required_ruby_version = nil
      s.platform = nil
      s.files = ["lib/cgikit", "lib/cgikit.rb", "lib/cgikit/components", "..."]
    end
    
    assert cgikit == cgikit
  end
end

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
    assert_equal Time.today,              @spec.date
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

end  # class TestComplexSpecification

class TestLegacyRubySpecification < Test::Unit::TestCase
  def setup
    @ruby_spec = File.read(LEGACY_GEM_SPEC_FILE)
  end

  def test_load_legacy
    s = gemspec = eval(@ruby_spec)
    assert_equal 'keyedlist', s.name
    assert_equal '0.4.0', s.version.to_s
    assert_equal true, s.has_rdoc?
    assert_equal Time.today, s.date
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
    @yaml_spec = File.read(LEGACY_GEM_YAML_FILE)
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

class TestSpecificationClassMethods < Test::Unit::TestCase
  def test_load
    gs = Gem::Specification.load("test/data/one/one.gemspec")
    assert_equal "one", gs.name
    assert_equal "one-0.0.1", gs.full_name
  end

  def test_normalize_input_with_183_yaml
    input = "!ruby/object:Gem::Specification "
    assert_equal "--- #{input}", Gem::Specification.normalize_yaml_input(input)
  end

  def test_normalize_input_with_non_183_yaml
    input = "--- !ruby/object:Gem::Specification "
    assert_equal input, Gem::Specification.normalize_yaml_input(input)
  end

  def test_normalize_input_with_183_io
    input = "!ruby/object:Gem::Specification "
    assert_equal "--- #{input}",
      Gem::Specification.normalize_yaml_input(StringIO.new(input))
  end

  def test_normalize_input_with_non_183_io
    input = "--- !ruby/object:Gem::Specification "
    assert_equal input,
      Gem::Specification.normalize_yaml_input(StringIO.new(input))
  end
end
