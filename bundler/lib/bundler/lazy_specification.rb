# frozen_string_literal: true

require_relative "force_platform"

module Bundler
  class LazySpecification
    include MatchMetadata
    include MatchPlatform
    include ForcePlatform

    attr_reader :name, :version, :platform, :materialization
    attr_accessor :source, :remote, :force_ruby_platform, :dependencies, :required_ruby_version,
      :required_rubygems_version, :overrides, :artifact_id

    #
    # For backwards compatibility with existing lockfiles, if the most specific
    # locked platform is not a specific platform like x86_64-linux or
    # universal-java-11, then we keep the previous behaviour of resolving the
    # best platform variant at materiliazation time. For previous bundler
    # versions (before 2.2.0) this was always the case (except when the lockfile
    # only included non-ruby platforms), but we're also keeping this behaviour
    # on newer bundlers unless users generate the lockfile from scratch or
    # explicitly add a more specific platform.
    #
    attr_accessor :most_specific_locked_platform

    alias_method :runtime_dependencies, :dependencies

    def self.from_spec(s)
      lazy_spec = new(s.name, s.version, s.platform, s.source)
      lazy_spec.dependencies = s.runtime_dependencies
      lazy_spec.required_ruby_version = s.required_ruby_version
      lazy_spec.required_rubygems_version = s.required_rubygems_version
      lazy_spec.overrides = s.overrides if s.is_a?(LazySpecification)
      lazy_spec.artifact_id = s.artifact_id if s.respond_to?(:artifact_id)
      lazy_spec
    end

    def initialize(name, version, platform, source = nil, **materialization_options)
      @name          = name
      @version       = version
      @dependencies  = []
      @required_ruby_version = Gem::Requirement.default
      @required_rubygems_version = Gem::Requirement.default
      @platform = platform || Gem::Platform::RUBY

      @original_source = source
      @source = source
      @materialization_options = materialization_options

      @force_ruby_platform = default_force_ruby_platform
      @most_specific_locked_platform = nil
      @materialization = nil
    end

    def missing?
      @materialization == self
    end

    def incomplete?
      @materialization.nil?
    end

    def source_changed?
      @original_source != source
    end

    def full_name
      @full_name ||= if platform == Gem::Platform::RUBY
        "#{@name}-#{@version}"
      else
        "#{@name}-#{@version}-#{platform}"
      end
    end

    def index_key
      return full_name unless artifact_id

      "#{full_name}-#{artifact_id}"
    end

    def lock_name
      @lock_name ||= name_tuple.lock_name
    end

    def name_tuple
      Gem::NameTuple.new(@name, @version, @platform)
    end

    def ==(other)
      index_key == (other.respond_to?(:index_key) ? other.index_key : other.full_name)
    end

    def eql?(other)
      self == other
    end

    def hash
      index_key.hash
    end

    ##
    # Does this locked specification satisfy +dependency+?
    #
    # NOTE: Rubygems default requirement is ">= 0", which doesn't match
    # prereleases of 0 versions, like "0.0.0.dev" or "0.0.0.SNAPSHOT". However,
    # bundler users expect those to work. We need to make sure that Gemfile
    # dependencies without explicit requirements (which use ">= 0" under the
    # hood by default) are still valid for locked specs using this kind of
    # versions. The method implements an ad-hoc fix for that. A better solution
    # might be to change default rubygems requirement of dependencies to be ">=
    # 0.A" but that's a major refactoring likely to break things. Hopefully we
    # can attempt it in the future.
    #

    def satisfies?(dependency)
      effective_requirement = dependency.requirement == Gem::Requirement.default ? Gem::Requirement.new(">= 0.A") : dependency.requirement

      @name == dependency.name && effective_requirement.satisfied_by?(Gem::Version.new(@version))
    end

    def to_lock
      out = String.new
      out << "    #{lock_name}\n"

      dependencies.sort_by(&:to_s).uniq.each do |dep|
        next if dep.type == :development
        out << "    #{dep.to_lock}\n"
      end

      out
    end

    def materialize_for_cache
      source.remote!

      materialize(self, &:first)
    end

    def materialized_for_installation
      @materialization = materialize_for_installation

      self unless incomplete?
    end

    def materialize_for_installation
      source.local!

      if use_exact_resolved_specifications?
        spec = materialize(self) {|specs| choose_compatible(specs, fallback_to_non_installable: false) }
        return spec if spec

        # Exact spec is incompatible; in frozen mode, try to find a compatible platform variant
        # In non-frozen mode, return nil to trigger re-resolution and lockfile update
        if Bundler.frozen_bundle?
          materialize([name, version]) {|specs| resolve_best_platform(specs) }
        end
      else
        materialize([name, version]) {|specs| resolve_best_platform(specs) }
      end
    end

    def inspect
      "#<#{self.class} @name=\"#{name}\" (#{full_name.delete_prefix("#{name}-")})>"
    end

    def to_s
      lock_name
    end

    def git_version
      return unless source.is_a?(Bundler::Source::Git)
      " #{source.revision[0..6]}"
    end

    def force_ruby_platform!
      @force_ruby_platform = true
    end

    def replace_source_with!(gemfile_source)
      return unless gemfile_source.can_lock?(self)

      @source = gemfile_source

      true
    end

    private

    def use_exact_resolved_specifications?
      !source.is_a?(Source::Path) && ruby_platform_materializes_to_ruby_platform?
    end

    # Try platforms in order of preference until finding a compatible spec.
    # Used for legacy lockfiles and as a fallback when the exact locked spec
    # is incompatible. Falls back to frozen bundle behavior if none match.
    def resolve_best_platform(specs)
      find_compatible_platform_spec(specs) || frozen_bundle_fallback(specs)
    end

    def find_compatible_platform_spec(specs)
      candidate_platforms.each do |plat|
        candidates = MatchPlatform.select_best_platform_match(specs, plat)
        spec = choose_compatible(candidates, fallback_to_non_installable: false)
        return spec if spec
      end
      nil
    end

    # Platforms to try in order of preference. Ruby platform is last since it
    # requires compilation, but works when precompiled gems are incompatible.
    def candidate_platforms
      target = source.is_a?(Source::Path) ? platform : Bundler.local_platform
      [target, platform, Gem::Platform::RUBY].uniq
    end

    # In frozen mode, accept any candidate. Will error at install time.
    # When target differs from locked platform, prefer locked platform's candidates
    # to preserve lockfile integrity.
    def frozen_bundle_fallback(specs)
      target = source.is_a?(Source::Path) ? platform : Bundler.local_platform
      fallback_platform = target == platform ? target : platform
      candidates = MatchPlatform.select_best_platform_match(specs, fallback_platform)
      choose_compatible(candidates)
    end

    def ruby_platform_materializes_to_ruby_platform?
      generic_platform = Bundler.generic_local_platform == Gem::Platform::JAVA ? Gem::Platform::JAVA : Gem::Platform::RUBY

      (most_specific_locked_platform != generic_platform) || force_ruby_platform || Bundler.settings[:force_ruby_platform]
    end

    def materialize(query)
      matching_specs = source.specs.search(query)
      return self if matching_specs.empty?

      yield matching_specs
    end

    # If in frozen mode, we fallback to a non-installable candidate because by
    # doing this we avoid re-resolving and potentially end up changing the
    # lockfile, which is not allowed. In that case, we will give a proper error
    # about the mismatch higher up the stack, right before trying to install the
    # bad gem.
    def choose_compatible(candidates, fallback_to_non_installable: Bundler.frozen_bundle?)
      override_list = overrides || []
      compatible = candidates.reverse.select do |spec|
        spec.is_a?(StubSpecification) || spec.matches_current_metadata_with_overrides?(override_list)
      end
      search = most_specific_ruby_requirement(compatible)
      if search.nil? && fallback_to_non_installable
        search = candidates.last
      end

      if search
        validate_dependencies(search) if search.platform == platform

        search.locked_platform = platform if search.instance_of?(RemoteSpecification) || search.instance_of?(EndpointSpecification)
      end
      search
    end

    def most_specific_ruby_requirement(specs)
      specs.max do |a, b|
        compare_ruby_requirement_specificity(a.required_ruby_version, b.required_ruby_version)
      end
    end

    def compare_ruby_requirement_specificity(a_requirement, b_requirement)
      lower_comparison = lower_ruby_bound(a_requirement) <=> lower_ruby_bound(b_requirement)
      return lower_comparison unless lower_comparison.zero?

      a_upper = upper_ruby_bound(a_requirement)
      b_upper = upper_ruby_bound(b_requirement)

      upper_comparison =
        if a_upper && b_upper
          b_upper <=> a_upper
        elsif a_upper
          1
        elsif b_upper
          -1
        else
          0
        end
      return upper_comparison unless upper_comparison.zero?

      a_requirement.requirements.length <=> b_requirement.requirements.length
    end

    def lower_ruby_bound(requirement)
      requirement.requirements.map do |operator, version|
        version if ["=", ">=", ">", "~>"].include?(operator)
      end.compact.max || Gem::Version.new("0")
    end

    def upper_ruby_bound(requirement)
      requirement.requirements.map do |operator, version|
        version if ["=", "<=", "<"].include?(operator)
      end.compact.min
    end

    # Validate dependencies of this locked spec are consistent with dependencies
    # of the actual spec that was materialized.
    #
    # Note that unless we are in strict mode (which we set during installation)
    # we don't validate dependencies of locally installed gems but
    # accept what's in the lockfile instead for performance, since loading
    # dependencies of locally installed gems would mean evaluating all gemspecs,
    # which would affect `bundler/setup` performance.
    def validate_dependencies(spec)
      if !@materialization_options[:strict] && spec.is_a?(StubSpecification)
        spec.dependencies = dependencies
      else
        if !source.is_a?(Source::Path) && spec.runtime_dependencies.sort != dependencies.sort
          raise IncorrectLockfileDependencies.new(self, spec.runtime_dependencies, dependencies)
        end
      end
    end
  end
end
