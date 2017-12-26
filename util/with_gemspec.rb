require 'rubygems'

begin
  require 'hoe'
rescue ::LoadError
  abort <<-ERR
Error while loading the hoe gem.
Please install it by running the following:

$ [sudo] gem install hoe
  ERR
end

def rubygems_spec
  Hoe.spec 'rubygems-update' do
    self.author         = ['Jim Weirich', 'Chad Fowler', 'Eric Hodel']
    self.email          = %w[rubygems-developers@rubyforge.org]
    self.readme_file    = 'README.md'

    license 'Ruby'
    license 'MIT'

    spec_extras[:required_rubygems_version] = Gem::Requirement.default
    spec_extras[:required_ruby_version]     = Gem::Requirement.new '>= 1.8.7'
    spec_extras[:executables]               = ['update_rubygems']
    spec_extras[:homepage]                  = 'https://rubygems.org'

    rdoc_locations <<
      'docs-push.seattlerb.org:/data/www/docs.seattlerb.org/rubygems/'

    clean_globs.push('**/debug.log',
                     '*.out',
                     '.config',
                     'data__',
                     'html',
                     'logs',
                     'graph.dot',
                     'pkgs/sources/sources*.gem',
                     'scripts/*.hieraki')

    extra_dev_deps.clear

    dependency 'builder',       '~> 2.1',   :dev
    dependency 'hoe-seattlerb', '~> 1.2',   :dev
    dependency 'rdoc',          '~> 4.0',   :dev
    dependency 'ZenTest',       '~> 4.5',   :dev
    dependency 'rake',          '~> 10.5',  :dev
    dependency 'minitest',      '~> 4.0',   :dev

    self.extra_rdoc_files = Dir["*.rdoc"] + %w[
      CVE-2013-4287.txt
      CVE-2013-4363.txt
    ]

    spec_extras['rdoc_options'] = proc do |rdoc_options|
      rdoc_options << "--title=RubyGems Update Documentation"
    end

    self.rsync_args += " --no-p -O"

    self.version = File.open('lib/rubygems.rb', 'r:utf-8') do |f|
      f.read[/VERSION\s+=\s+(['"])(#{Gem::Version::VERSION_PATTERN})\1/, 2]
    end

    spec_extras['require_paths'] = %w[hide_lib_for_update]
  end
end
