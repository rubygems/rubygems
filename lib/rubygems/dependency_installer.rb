require 'rubygems'
require 'rubygems/dependency_list'
require 'rubygems/installer'

class Gem::DependencyInstaller

  attr_reader :gems_to_install
  attr_reader :installed_gems

  def initialize(gem_name)
    @gem_name = gem_name
    @installed_gems = []

    @specs_and_sources = Gem::SourceInfoCache.search_with_source @gem_name
    @specs = @specs_and_sources.map { |spec,_| spec }

    gather_dependencies
  end

  def download(spec, source_uri)
    gem_file_name = "#{spec.full_name}.gem"
    local_gem_path = File.join Gem.dir, 'cache', gem_file_name

    unless File.exist? local_gem_path then
      remote_gem_path = "#{source_uri}/gems/#{gem_file_name}"

      gem = Gem::RemoteFetcher.fetcher.fetch_path remote_gem_path

      File.open local_gem_path, 'wb' do |fp|
        fp.write gem
      end
    end

    local_gem_path
  end

  def gather_dependencies
    dependency_list = Gem::DependencyList.new
    dependency_list.add(*@specs)

    to_do = @specs.dup
    seen = {}

    until to_do.empty? do
      spec = to_do.shift
      next if spec.nil? or seen[spec]
      seen[spec] = true

      spec.dependencies.each do |dep|
        results = Gem::SourceInfoCache.search_with_source dep

        results.each do |dep_spec, source_uri|
          next unless Gem.platforms.include? dep_spec.platform
          next if seen[dep_spec]
          @specs_and_sources << [dep_spec, source_uri]
          dependency_list.add dep_spec
          to_do.push dep_spec
        end
      end
    end

    @gems_to_install = dependency_list.dependency_order
  end

  def install
    @gems_to_install.each do |spec|
      source_uri = @specs_and_sources.assoc spec
      local_gem_path = download spec, source_uri

      Gem::Installer.new(local_gem_path).install

      @installed_gems << spec
    end
  end

end

