# frozen_string_literal: true

RSpec.describe Bundler::MatchMetadata do
  let(:klass) do
    Class.new do
      include Bundler::MatchMetadata

      attr_accessor :required_ruby_version, :required_rubygems_version, :dependencies

      def initialize(ruby_version, rubygems_version)
        @required_ruby_version = ruby_version
        @required_rubygems_version = rubygems_version
        @dependencies = []
      end

      alias_method :runtime_dependencies, :dependencies
    end
  end

  describe "#matches_current_ruby?" do
    context "when the ruby version has an upper bound that excludes the current ruby" do
      let(:spec) { klass.new(Gem::Requirement.new(">= 3.0", "< 3.1"), Gem::Requirement.default) }

      it "returns false by default" do
        expect(spec.matches_current_ruby?).to be false
      end

      it "returns true when ignore_ruby_upper_bounds is set" do
        bundle "config set ignore_ruby_upper_bounds true"
        expect(spec.matches_current_ruby?).to be true
      end
    end

    context "when the ruby version has only a lower bound" do
      let(:spec) { klass.new(Gem::Requirement.new(">= 2.0"), Gem::Requirement.default) }

      it "returns true regardless of setting" do
        expect(spec.matches_current_ruby?).to be true

        bundle "config set ignore_ruby_upper_bounds true"
        expect(spec.matches_current_ruby?).to be true
      end
    end

    context "when the ruby version has only an upper bound" do
      let(:spec) { klass.new(Gem::Requirement.new("< 3.1"), Gem::Requirement.default) }

      it "returns false by default" do
        expect(spec.matches_current_ruby?).to be false
      end

      it "returns true when ignore_ruby_upper_bounds is set (upper bound removed, defaults to >= 0)" do
        bundle "config set ignore_ruby_upper_bounds true"
        expect(spec.matches_current_ruby?).to be true
      end
    end
  end

  describe "#matches_current_rubygems?" do
    context "when the rubygems version has an upper bound that excludes the current rubygems" do
      let(:spec) { klass.new(Gem::Requirement.default, Gem::Requirement.new(">= 3.0", "< 3.1")) }

      it "returns false by default" do
        expect(spec.matches_current_rubygems?).to be false
      end

      it "returns true when ignore_rubygems_upper_bounds is set" do
        bundle "config set ignore_rubygems_upper_bounds true"
        expect(spec.matches_current_rubygems?).to be true
      end
    end

    context "when the rubygems version has only a lower bound" do
      let(:spec) { klass.new(Gem::Requirement.default, Gem::Requirement.new(">= 2.0")) }

      it "returns true regardless of setting" do
        expect(spec.matches_current_rubygems?).to be true

        bundle "config set ignore_rubygems_upper_bounds true"
        expect(spec.matches_current_rubygems?).to be true
      end
    end
  end

  describe "#metadata_dependency" do
    context "when ignore_ruby_upper_bounds is set" do
      before { bundle "config set ignore_ruby_upper_bounds true" }

      it "removes upper bounds from Ruby dependency" do
        spec = klass.new(Gem::Requirement.new(">= 3.0", "< 3.1"), Gem::Requirement.default)
        dep = spec.send(:metadata_dependency, "Ruby", spec.required_ruby_version)
        expect(dep.requirement).to eq(Gem::Requirement.new(">= 3.0"))
      end

      it "returns nil when only upper bounds exist" do
        spec = klass.new(Gem::Requirement.new("< 3.1"), Gem::Requirement.default)
        dep = spec.send(:metadata_dependency, "Ruby", spec.required_ruby_version)
        expect(dep).to be_nil
      end

      it "does not affect RubyGems dependency" do
        spec = klass.new(Gem::Requirement.default, Gem::Requirement.new(">= 3.0", "< 4.0"))
        dep = spec.send(:metadata_dependency, "RubyGems", spec.required_rubygems_version)
        expect(dep.requirement).to eq(Gem::Requirement.new(">= 3.0", "< 4.0"))
      end
    end

    context "when ignore_rubygems_upper_bounds is set" do
      before { bundle "config set ignore_rubygems_upper_bounds true" }

      it "removes upper bounds from RubyGems dependency" do
        spec = klass.new(Gem::Requirement.default, Gem::Requirement.new(">= 3.0", "< 4.0"))
        dep = spec.send(:metadata_dependency, "RubyGems", spec.required_rubygems_version)
        expect(dep.requirement).to eq(Gem::Requirement.new(">= 3.0"))
      end

      it "does not affect Ruby dependency" do
        spec = klass.new(Gem::Requirement.new(">= 3.0", "< 3.1"), Gem::Requirement.default)
        dep = spec.send(:metadata_dependency, "Ruby", spec.required_ruby_version)
        expect(dep.requirement).to eq(Gem::Requirement.new(">= 3.0", "< 3.1"))
      end
    end
  end
end
