class Gem::DependencyResolver::InstallerSet

  ##
  # Gem::Specification objects that must always be installed.

  attr_reader :always_install

  def initialize domain
    @domain = domain

    @f = Gem::SpecFetcher.fetcher

    @all = Hash.new { |h,k| h[k] = [] }

    list, _ = @f.available_specs(:released)

    list.each do |uri, specs|
      specs.each do |n|
        @all[n.name] << [uri, n]
      end
    end

    @always_install = []
    @specs          = {}
  end

  ##
  # Should local gems should be considered?

  def consider_local?
    @domain == :both or @domain == :local
  end

  ##
  # Should remote gems should be considered?

  def consider_remote?
    @domain == :both or @domain == :remote
  end

  ##
  # Returns an array of IndexSpecification objects matching DependencyRequest
  # +req+.

  def find_all req
    res = []

    dep  = req.dependency
    name = dep.name

    dep.matching_specs.each do |gemspec|
      next if @always_install.include? gemspec

      res << Gem::DependencyResolver::InstalledSpecification.new(self, gemspec)
    end

    if consider_local? then
      source = Gem::Source::Local.new

      if spec = source.find_gem(name, dep.requirement) then
        res << Gem::DependencyResolver::IndexSpecification.new(
          self, spec.name, spec.version, source, spec.platform)
      end
    end

    if consider_remote? then
      @all[name].each do |source, n|
        if dep.match? n then
          res << Gem::DependencyResolver::IndexSpecification.new(
            self, n.name, n.version, source, n.platform)
        end
      end
    end

    res
  end

  def inspect # :nodoc:
    '#<%s domain: %s specs: %p>' % [ self.class, @domain, @specs.keys ]
  end

  ##
  # Called from IndexSpecification to get a true Specification
  # object.

  def load_spec name, ver, source
    key = "#{name}-#{ver}"
    @specs[key] ||= source.fetch_spec Gem::NameTuple.new name, ver
  end

  ##
  # No prefetching needed since we load the whole index in initially.

  def prefetch(reqs)
  end

end

