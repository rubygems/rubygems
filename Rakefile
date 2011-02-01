# -*- ruby -*-

$:.unshift 'lib'

require 'rubygems'
require 'rubygems/package_task'

# HACK bootstrap load_yaml, remove after 1.5 release
def Gem.load_yaml; end unless Gem.respond_to? :load_yaml

begin
  require 'psych'
rescue ::LoadError
  require 'yaml'
end

require 'hoe'

Hoe::RUBY_FLAGS << " --disable-gems" if RUBY_VERSION > "1.9"

Hoe.plugin :minitest
Hoe.plugin :git
Hoe.plugin :rubyforge

hoe = Hoe.spec 'rubygems-update' do
  self.rubyforge_name = 'rubygems'
  self.author         = ['Jim Weirich', 'Chad Fowler', 'Eric Hodel']
  self.email          = %w[rubygems-developers@rubyforge.org]
  self.readme_file    = 'README.rdoc'

  spec_extras[:required_rubygems_version] = Gem::Requirement.default
  spec_extras[:required_ruby_version]     = Gem::Requirement.new '>= 1.8.7'
  spec_extras[:executables]               = ['update_rubygems']

  clean_globs.push('**/debug.log',
                   '*.out',
                   '.config',
                   'data__',
                   'html',
                   'logs',
                   'graph.dot',
                   'pkgs/sources/sources*.gem',
                   'scripts/*.hieraki')

  extra_dev_deps << ['builder', '~> 2.1']
  extra_dev_deps << ['hoe-seattlerb', '~> 1.2']
  extra_dev_deps << ['session', '~> 2.4']

  self.extra_rdoc_files = Dir["*.rdoc"]

  spec_extras['rdoc_options'] = proc do |rdoc_options|
    rdoc_options << "--title=RubyGems #{self.version} Documentation"
  end

  # FIX: this exists because update --system installs the gem and
  # doesn't uninstall it. It should uninstall or better, not install
  # in the first place.
  spec_extras['require_paths'] = %w[hide_lib_for_update] unless
    ENV['RAKE_SUCKS']
end

task :docs => :rake_sucks
task :rake_sucks do
  # This exists ENTIRELY because the rake design convention of
  # RDocTask.new is broken. Because most of the work is being done
  # inside initialize(?!?) BEFORE tasks are even running, too much
  # stuff is set in stone, and we can't deal with the require_paths
  # issue above.
  unless ENV['RAKE_SUCKS'] then
    ENV['RAKE_SUCKS'] = "1"
    rm_rf "doc"
    sh "rake docs"
  end
end

desc "Run just the functional tests"
Rake::TestTask.new(:test_functional) do |t|
  t.test_files = FileList['test/functional*.rb']
  t.warning = true
end

# --------------------------------------------------------------------
# Creating a release

task :prerelease => [:clobber, :check_manifest, :test, :test_functional]

task :postrelease => :publish_docs

pkg_dir_path = "pkg/rubygems-update-#{hoe.version}"
task :package do
  mv pkg_dir_path, "pkg/rubygems-#{hoe.version}"
  Dir.chdir 'pkg' do
    sh "tar -czf rubygems-#{hoe.version}.tgz rubygems-#{hoe.version}"
    sh "zip -q -r rubygems-#{hoe.version}.zip rubygems-#{hoe.version}"
  end
end

# Misc Tasks ---------------------------------------------------------

# These tasks expect to have the following directory structure:
#
#   git/git.rubini.us/code # Rubinius git HEAD checkout
#   svn/ruby/trunk         # ruby subversion HEAD checkout
#   svn/rubygems/trunk     # RubyGems subversion HEAD checkout
#
# If you don't have this directory structure, set RUBY_PATH and/or
# RUBINIUS_PATH.

def rsync_with dir
  rsync_options = "-avP --exclude '*svn*' --exclude '*swp' --exclude '*rbc'" +
    " --exclude '*.rej' --exclude '*.orig' --exclude 'lib/rubygems/defaults/*'"
  sh "rsync #{rsync_options} bin/gem             #{dir}/bin/gem"
  sh "rsync #{rsync_options} lib/                #{dir}/lib"
  sh "rsync #{rsync_options} test/               #{dir}/test/rubygems"
  sh "rsync #{rsync_options} util/gem_prelude.rb #{dir}/gem_prelude.rb"
end

def diff_with dir
  diff_options = "-urpN --exclude '*svn*' --exclude '*swp' --exclude '*rbc'"
  sh "diff #{diff_options} bin/gem             #{dir}/bin/gem;         true"
  sh "diff #{diff_options} lib/ubygems.rb      #{dir}/lib/ubygems.rb;  true"
  sh "diff #{diff_options} lib/rubygems.rb     #{dir}/lib/rubygems.rb; true"
  sh "diff #{diff_options} lib/rubygems        #{dir}/lib/rubygems;    true"
  sh "diff #{diff_options} lib/rbconfig        #{dir}/lib/rbconfig;    true"
  sh "diff #{diff_options} test                #{dir}/test/rubygems;   true"
  sh "diff #{diff_options} util/gem_prelude.rb #{dir}/gem_prelude.rb;  true"
end

rubinius_dir = ENV['RUBINIUS_PATH'] || '../../../git/git.rubini.us/code'
ruby_dir     = ENV['RUBY_PATH']     || '../../ruby/trunk'

desc "Updates Ruby HEAD with the currently checked-out copy of RubyGems."
task :update_ruby do
  rsync_with ruby_dir
end

desc "Updates Rubinius HEAD with the currently checked-out copy of RubyGems."
task :update_rubinius do
  rsync_with rubinius_dir
end

desc "Diffs Ruby HEAD with the currently checked-out copy of RubyGems."
task :diff_ruby do
  diff_with ruby_dir
end

desc "Diffs Rubinius HEAD with the currently checked-out copy of RubyGems."
task :diff_rubinius do
  diff_with rubinius_dir
end

desc "Get coverage for a specific test, no system RubyGems."
task "rcov:for", [:test] do |task, args|
  mgem  = Gem.source_index.find_name("minitest").first rescue nil
  rgem  = Gem.source_index.find_name(/rcov/).first
  libs  = rgem.require_paths.map { |p| File.join rgem.full_gem_path, p }
  rcov  = File.join rgem.full_gem_path, rgem.bindir, rgem.default_executable

  if mgem
    libs << mgem.require_paths.map { |p| File.join mgem.full_gem_path, p }
  end

  libs << "lib:test"

  flags  = []
  flags << "-I" << libs.flatten.join(":")

  rflags  = []
  rflags << "-i" << "lib/rubygems"

  ruby "#{flags.join ' '} #{rcov} #{rflags.join ' '} #{args[:test]}"
end

