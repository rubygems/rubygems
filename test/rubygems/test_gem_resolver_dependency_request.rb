require 'rubygems/test_case'

class TestGemResolverDependencyRequest < Gem::TestCase

  def setup
    super

    @DR = Gem::Resolver::DependencyRequest
  end

  def test_development_eh
    a_dep = dep 'a', '>= 1'

    a_dep_req = @DR.new a_dep, nil

    refute a_dep_req.development?

    b_dep = dep 'b', '>= 1', :development

    b_dep_req = @DR.new b_dep, nil

    assert b_dep_req.development?
  end

  def test_requirement
    dependency = dep 'a', '>= 1'

    dr = @DR.new dependency, nil

    assert_equal dependency, dr.dependency
  end

end

