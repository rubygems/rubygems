require 'rubygems/test_case'
require 'rubygems/request_set'

class TestGemRequestSetGemDependencyAPI < Gem::TestCase

  def setup
    super

    @GDA = Gem::RequestSet::GemDependencyAPI

    @set = Gem::RequestSet.new
  end

  def test_gem
    gda = @GDA.new @set, nil

    gda.gem 'a'

    assert_equal [dep('a')], @set.dependencies
  end

  def test_gem_requirement
    gda = @GDA.new @set, nil

    gda.gem 'a', '~> 1.0'

    assert_equal [dep('a', '~> 1.0')], @set.dependencies
  end

  def test_gem_requirements
    gda = @GDA.new @set, nil

    gda.gem 'b', '~> 1.0', '>= 1.0.2'

    assert_equal [dep('b', '~> 1.0', '>= 1.0.2')], @set.dependencies
  end

  def test_gem_requirements_options
    gda = @GDA.new @set, nil

    gda.gem 'c', :git => 'https://example/c.git'

    assert_equal [dep('c')], @set.dependencies
  end

  def test_load
    Tempfile.open 'Gemfile' do |io|
      io.puts 'gem "a"'
      io.flush

      gda = @GDA.new @set, io.path

      gda.load

      assert_equal [dep('a')], @set.dependencies
    end
  end

  def test_name_typo
    assert_same @GDA, Gem::RequestSet::DepedencyAPI
  end

end

