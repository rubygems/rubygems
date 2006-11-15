require 'test/unit'
require 'rubygems'

class TestGem < Test::Unit::TestCase

  def test_self_configuration
    expected = {}
    Gem.send :instance_variable_set, :@configuration, nil

    assert_equal expected, Gem.configuration

    Gem.configuration[:verbose] = true
    expected[:verbose] = true

    assert_equal expected, Gem.configuration
    assert_equal true, Gem.configuration.verbose, 'method_missing on Hash'
  end

end

