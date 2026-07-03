# frozen_string_literal: true

require_relative "helper"

class TestGemResolverActivationRequest < Gem::TestCase
  def setup
    super

    @dep = Gem::Resolver::DependencyRequest.new dep("a", ">= 0"), nil

    source   = Gem::Source::Local.new
    platform = Gem::Platform::RUBY

    @a3 = Gem::Resolver::IndexSpecification.new nil, "a", v(3), source, platform

    @req = Gem::Resolver::ActivationRequest.new @a3, @dep
  end

  def test_development_eh
    refute @req.development?

    dep_req = Gem::Resolver::DependencyRequest.new dep("a", ">= 0", :development), nil

    act_req = Gem::Resolver::ActivationRequest.new @a3, dep_req

    assert act_req.development?
  end

  def test_full_name
    assert_equal "a-3", @req.full_name

    set = Gem::Resolver::APISet.new
    data = { name: "a", number: "1", suffix: "bd0ec167", dependencies: [],
             requirements: { platform: ["= arm64-darwin"] } }
    ca = Gem::Resolver::ActivationRequest.new(
      Gem::Resolver::APISpecification.new(set, data), @dep
    )

    assert_equal "a-1-bd0ec167", ca.full_name
  end

  def test_inspect
    assert_match "a-3",                         @req.inspect
    assert_match "from a (>= 0)",               @req.inspect
  end

  def test_installed_eh
    v_spec = Gem::Resolver::VendorSpecification.new nil, @a3

    @req = Gem::Resolver::ActivationRequest.new v_spec, @dep

    assert @req.installed?
  end
end
