require 'test/unit'
require 'rubygems'

class TestValidator < Test::Unit::TestCase
  def test_missing_gem_throws_error
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem_file("")
    }
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem_file("/this/path/will/almost/definitely/not/exist.gem")
    }
  end

  def test_invalid_gem_throws_error
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem("")
    }
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem(@simple_gem.upcase)
    }
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem(@simple_gem.reverse)
    }
  end

  def test_simple_valid_gem_verifies
    assert_nothing_raised {
      Gem::Validator.new.verify_gem(@simple_gem)
    }
  end

  def test_truncated_simple_valid_gem_fails
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem(@simple_gem.chop)
    }
  end

  def test_invalid_checksum_fails_appropriately
    assert_raises(Gem::VerificationError) {
      Gem::Validator.new.verify_gem(@simple_gem.sub(/MD5SUM.*=.*/, 'MD5SUM = "foo"'))
    }
  end

  def setup
    require File.dirname(__FILE__) + "/simple_gem.rb"
    @simple_gem = SIMPLE_GEM
  end
end
