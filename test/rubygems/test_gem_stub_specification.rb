require "rubygems/test_case"
require "rubygems/stub_specification"

class TestStubSpecification < Gem::TestCase
  SPECIFICATIONS = File.expand_path(File.join("..", "specifications"), __FILE__)
  FOO = File.join SPECIFICATIONS, "foo-0.0.1.gemspec"
  BAR = File.join SPECIFICATIONS, "bar-0.0.2.gemspec"

  def test_initialize
    stub = Gem::StubSpecification.new(FOO)
    assert_equal "foo", stub.name
    assert_equal Gem::Version.new("0.0.1"), stub.version
    assert_equal Gem::Platform.new("mswin32"), stub.platform
    assert_equal ["lib", "lib/f oo/ext"], stub.require_paths
  end

  def test_initialize_extension
    Tempfile.open 'stub' do |io|
      io.write <<-STUB
# -*- encoding: utf-8 -*-
# stub: a 2 ruby lib
# stub: ext/a/extconf.rb
      STUB

      io.flush

      stub = Gem::StubSpecification.new io.path
      gem_dir = File.join stub.gems_dir, stub.full_name

      lib = Pathname File.join gem_dir, 'lib'

      ext_install_dir =
        Pathname(stub.extension_install_dir).relative_path_from lib
      ext_install_dir = ext_install_dir.to_s

      assert_equal 'a',                      stub.name
      assert_equal v(2),                     stub.version
      assert_equal Gem::Platform::RUBY,      stub.platform
      assert_equal ['lib', ext_install_dir], stub.require_paths
      assert_equal %w[ext/a/extconf.rb],     stub.extensions
    end
  end

  def test_initialize_missing_stubline
    stub = Gem::StubSpecification.new(BAR)
    assert_equal "bar", stub.name
    assert_equal Gem::Version.new("0.0.2"), stub.version
    assert_equal Gem::Platform.new("ruby"), stub.platform
    assert_equal ["lib"], stub.require_paths
  end

  def test_full_require_paths
    stub = stub_with_extension

    expected = [
      File.join(stub.full_gem_path, 'lib'),
      stub.extension_install_dir,
    ]

    assert_equal expected, stub.full_require_paths
  end

  def test_to_spec
    stub = Gem::StubSpecification.new(FOO)
    assert stub.to_spec.is_a?(Gem::Specification)
    assert_equal "foo", stub.to_spec.name
  end

  def stub_with_extension
    Tempfile.open 'stub' do |io|
      io.write <<-STUB
# -*- encoding: utf-8 -*-
# stub: a 2 ruby lib
# stub: ext/a/extconf.rb
      STUB

      io.flush

      return Gem::StubSpecification.new io.path
    end
  end

end

