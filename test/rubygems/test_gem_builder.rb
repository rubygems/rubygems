require 'rubygems/test_case'
require 'rubygems/builder'
require 'rubygems/package'

class TestGemBuilder < Gem::TestCase

  def test_build
    builder = Gem::Builder.new quick_spec('a')

    use_ui @ui do
      Dir.chdir @tempdir do
        builder.build
      end
    end

    assert_match %r|Successfully built RubyGem\n  Name: a|, @ui.output
  end

  def test_build_validates
    builder = Gem::Builder.new Gem::Specification.new

    assert_raises Gem::InvalidSpecificationException do
      builder.build
    end
  end

  def test_build_specification_result
    util_make_gems

    spec = build_gem_and_yield_spec @a1
    
    omit = %w[@loaded_from @loaded]

    if RUBY_VERSION > '1.9'
      omit.map!(&:to_sym)
    end

    (@a1.instance_variables - omit).each do |ivar|
      assert_equal(
        @a1.instance_variable_get(ivar), 
        spec.instance_variable_get(ivar), 
        "#{ivar} is equivalent between built spec and existing spec"
      )
    end
  end

  def build_gem_and_yield_spec(spec)
    builder = Gem::Builder.new spec

    spec = Dir.chdir @tempdir do
      FileUtils.mkdir 'lib'
      File.open('lib/code.rb', 'w') { |f| f << "something" }
      Gem::Package.open(File.open(builder.build)) { |x| x.metadata }
    end
  end
end
