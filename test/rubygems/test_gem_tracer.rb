require 'rubygems/test_case'
require 'rubygems/tracer'

class TestGemTracer < Gem::TestCase

  def setup
    super

    @tracer = Gem::Tracer.new
    Gem::Tracer.current_tracer = @tracer
  end

  def teardown
    super

    Gem::Tracer.current_tracer = nil
  end

  def test_add_span
    span = @tracer.span "test"
    assert_equal "test", span.description
    sleep 1
    span.stop!

    assert_in_delta 1.0, span.runtime, 0.1, "time is broken"
  end

  def test_spans_have_parents
    parent = @tracer.span "parent"
    span = @tracer.span "child"

    assert_equal parent, span.parent
  end

  def test_s_span
    Gem::Tracer.span("blah") {}
    assert_equal 1, @tracer.toplevel.children.size
  end
end
