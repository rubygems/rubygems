# -*- ruby -*-

$:.unshift 'lib'

require 'rubygems'
require 'rubygems/package_task'

require 'hoe'

Hoe::RUBY_FLAGS << " --disable-gems" if RUBY_VERSION > "1.9"

Hoe.plugin :minitest

hoe = Hoe.spec 'rubygems-update' do
  self.rubyforge_name = 'rubygems'
  self.author         = ['Jim Weirich', 'Chad Fowler', 'Eric Hodel']
  self.email          = %w[rubygems-developers@rubyforge.org]
  self.readme_file    = 'README.rdoc'
  self.need_zip       = false
  self.need_tar       = false

  spec_extras[:required_rubygems_version] = Gem::Requirement.default
  spec_extras[:required_ruby_version]     = Gem::Requirement.new '> 1.8.3'
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
  extra_dev_deps << ['minitest', '~> 1.4']
  extra_dev_deps << ['session', '~> 2.4']

  self.extra_rdoc_files = Dir["*.rdoc"]

  spec_extras['rdoc_options'] = proc do |rdoc_options|
    rdoc_options << "--title=RubyGems #{self.version} Documentation"
  end
  spec_extras['require_paths'] = %w[hide_lib_for_update]
end

desc "Run just the functional tests"
Rake::TestTask.new(:test_functional) do |t|
  t.test_files = FileList['test/functional*.rb']
  t.warning = true
end

# --------------------------------------------------------------------
# Creating a release

# It's good to have RG's development dependencies expressed in the Hoe
# block above, but including them in the rubygems-update gemspec makes
# it very difficult for people on old RG versions to install it,
# especially since they're working against stub legacy indexes
# now. Remove 'em before building the gem.

task :debug_gem => :scrub_dev_deps
Rake::Task[:gem].prerequisites.unshift :scrub_dev_deps

task :scrub_dev_deps do
  hoe.spec.dependencies.reject! { |d| :development == d.type }
end

task :prerelease => [:clobber, :sanity_check, :test, :test_functional]

task :postrelease => [:tag, :publish_docs]

pkg_dir_path = "pkg/rubygems-update-#{hoe.version}"
task :package do
  mv pkg_dir_path, "pkg/rubygems-#{hoe.version}"
  Dir.chdir 'pkg' do
    sh "tar -czf rubygems-#{hoe.version}.tgz rubygems-#{hoe.version}"
    sh "zip -q -r rubygems-#{hoe.version}.zip rubygems-#{hoe.version}"
  end
end

task :sanity_check do
  abort "svn status dirty. commit or revert them" unless `svn st`.empty?
end

task :tag => :sanity_check do
  raise "need a git version of rake tag written"
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

task :graph do
  $: << File.expand_path("~/Work/p4/zss/src/graph/dev/lib")
  require 'graph'
  deps = Graph.new
  deps.rotate

  current = nil
  `rake -P -s`.each_line do |line|
    case line
    when /^rake (.+)/
      current = $1
      deps[current] if current # force the node to exist, in case of a leaf
    when /^\s+(.+)/
      deps[current] << $1 if current
    else
      warn "unparsed: #{line.chomp}"
    end
  end


  deps.boxes
  deps.save "graph", nil
end

