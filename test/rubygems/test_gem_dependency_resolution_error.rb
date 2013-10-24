require 'rubygems/test_case'

class TestGemDependencyResolutionError < Gem::TestCase

  def setup
    super

    @DR = Gem::DependencyResolver

    @spec = quick_spec 'a', 2

    @a1_req = @DR::DependencyRequest.new dep('a', '= 1'), nil
    @a2_req = @DR::DependencyRequest.new dep('a', '= 2'), nil

    @activated = @DR::ActivationRequest.new @spec, @a2_req

    @conflict = @DR::DependencyConflict.new @a1_req, @activated

    @error = Gem::DependencyResolutionError.new @conflict
  end

  def test_message
    expected = <<-EXPECTED
conflicting dependencies a (= 1) and a (= 2)
  Activated a-2 instead of (= 1) via:
    
    EXPECTED

    assert_equal expected, @error.message
  end

end

