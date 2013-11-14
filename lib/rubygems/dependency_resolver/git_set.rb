##
# A GitSet represents gems that are sourced from git repositories.
#
# This is used for gem dependency file support.
#
# Example:
#
#   set = Gem::DependencyResolver::GitSet.new
#   set.add_git_gem 'rake', 'git://example/rake.git', tag: 'rake-10.1.0'

class Gem::DependencyResolver::GitSet < Gem::DependencyResolver::Set

  ##
  # A Hash containing git gem names for keys and a Hash of repository and
  # git commit reference as values.

  attr_reader :repositories # :nodoc:

  ##
  # A hash of gem names to Gem::DependencyResolver::GitSpecifications

  attr_reader :specs # :nodoc:

  def initialize # :nodoc:
    @git          = ENV['git'] || 'git'
    @repositories = {}
    @specs        = {}
  end

  def add_git_gem name, repository, reference # :nodoc:
    @repositories[name] = [repository, reference]
  end

  ##
  # Finds all git gems matching +req+

  def find_all req
    specs = @repositories.map do |name, _, _|
      load_spec name, nil, nil, nil
    end

    specs.select do |spec|
      req.matches_spec? spec
    end
  end

  def load_spec name, version, platform, source # :nodoc:
    source = Gem::Source::Git.new name, *@repositories[name]

    source.update

    gemspec = File.join source.install_dir, "#{name}.gemspec"

    spec = Gem::Specification.load gemspec

    Gem::DependencyResolver::GitSpecification.new self, spec, source
  end

  ##
  # Prefetches specifications from the git repositories in this set.

  def prefetch reqs
    names = reqs.map { |req| req.name }

    @repositories.each do |name, (repository, reference)|
      next unless names.include? name

      source = Gem::Source::Git.new name, repository, reference

      spec = source.load_spec name

      git_spec =
        Gem::DependencyResolver::GitSpecification.new self, spec, source

      @specs[name] = git_spec
    end
  end

end

