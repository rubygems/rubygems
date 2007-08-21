require 'rubygems'
require 'rubygems/dependency_list'
require 'rubygems/installer'

class Gem::DependencyInstaller

  attr_reader :gems_to_install
  attr_reader :installed_gems

  def initialize(gem_name)
    @gem_name = gem_name
    @installed_gems = []
    @specs_and_sources = []

    @specs_and_sources.push(*find_gems_with_sources(gem_name))

    gather_dependencies
  end

  def find_gems_with_sources(dep)
    gem_name = String === dep ? dep : dep.name

    gems_and_sources = []

    Dir[File.join(Dir.pwd, "#{gem_name}-[0-9]*.gem")].each do |gem_file|
      spec = Gem::Format.from_file_by_path(gem_file).spec
      gems_and_sources << [spec, gem_file] if spec.name == gem_name
    end

    gems_and_sources.push(*Gem::SourceInfoCache.search_with_source(gem_name))
  end

  def download(spec, source_uri)
    gem_file_name = "#{spec.full_name}.gem"
    local_gem_path = File.join Gem.dir, 'cache', gem_file_name
    source_uri = URI.parse source_uri

    case source_uri.scheme
    when 'http' then
      unless File.exist? local_gem_path then
        remote_gem_path = source_uri + "/gems/#{gem_file_name}"

        gem = Gem::RemoteFetcher.fetcher.fetch_path remote_gem_path

        File.open local_gem_path, 'wb' do |fp|
          fp.write gem
        end
      end
    when nil, 'file' then # TODO test for local overriding cache
      FileUtils.cp source_uri.to_s, local_gem_path
    else
      raise Gem::InstallError, "unsupported URI scheme #{source_uri.scheme}"
    end

    local_gem_path
  end

  def gather_dependencies
    specs = @specs_and_sources.map { |spec,_| spec }

    dependency_list = Gem::DependencyList.new
    dependency_list.add(*specs)

    to_do = specs.dup
    seen = {}

    until to_do.empty? do
      spec = to_do.shift
      next if spec.nil? or seen[spec]
      seen[spec] = true

      spec.dependencies.each do |dep|
        results = find_gems_with_sources dep

        results.each do |dep_spec, source_uri|
          next unless Gem.platforms.include? dep_spec.platform
          next if seen[dep_spec]
          @specs_and_sources << [dep_spec, source_uri]
          dependency_list.add dep_spec
          to_do.push dep_spec
        end
      end
    end

    @gems_to_install = dependency_list.dependency_order.reverse
  end

  def install
    @gems_to_install.each do |spec|
      _, source_uri = @specs_and_sources.assoc spec
      local_gem_path = download spec, source_uri

      Gem::Installer.new(local_gem_path).install

      @installed_gems << spec
    end
  end

end

