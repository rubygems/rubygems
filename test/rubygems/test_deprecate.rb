require 'rubygems/test_case'
require 'rubygems/builder'
require 'rubygems/package'

require 'rubygems/deprecate'

class TestDeprecate < Gem::TestCase

  def test_defaults
    assert_equal true, Deprecate.skip
  end
  
  def test_assignment
    Deprecate.skip = false
    
    assert_equal false, Deprecate.skip
    
    Deprecate.skip = nil

    assert_equal true, Deprecate.skip

    Deprecate.skip = false

    assert_equal false, Deprecate.skip
    
    Deprecate.skip = nil
  end
  
  def test_skip
    Deprecate.skip = false
    
    Deprecate.skip_during do
      assert_equal true, Deprecate.skip
    end

    Deprecate.skip_during(false) do
      assert_equal false, Deprecate.skip
    end
    
    Deprecate.skip_during(nil) do
      assert_equal true, Deprecate.skip
    end

    Deprecate.skip = nil
  end
end
