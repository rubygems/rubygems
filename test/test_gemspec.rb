# frozen_string_literal: true

require_relative "rubygems/helper"

class GemspecTest < Test::Unit::TestCase
  def setup
    @gemspec = Gem::Specification.load(File.expand_path("../rubygems-update.gemspec", __dir__))
  end

  def test_gemspec_version
    assert_equal Gem::Version, @gemspec.version.class
    assert_equal Gem::VERSION, @gemspec.version.to_s
  end
end
