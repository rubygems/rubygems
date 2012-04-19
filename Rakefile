# -*- ruby -*-

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
# Hoe.plugin :isolate

hoe = Hoe.spec 'rubygems-update' do
  self.rubyforge_name = 'rubygems'
  self.author         = ['Jim Weirich', 'Chad Fowler', 'Eric Hodel']
  self.email          = %w[rubygems-developers@rubyforge.org]
  self.readme_file    = 'README.rdoc'

  spec_extras[:required_rubygems_version] = Gem::Requirement.default
  spec_extras[:required_ruby_version]     = Gem::Requirement.new '>= 1.8.7'
  spec_extras[:executables]               = ['update_rubygems']

  rdoc_locations <<
    'rubyforge.org:/var/www/gforge-projects/rubygems/rubygems-update/'

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
  extra_dev_deps << ['rdoc', '~> 3.0']
  extra_dev_deps << ['rcov', '~> 0.9.0']
  extra_dev_deps << ['ZenTest', '~> 4.5']

  self.extra_rdoc_files = Dir["*.rdoc"]

  spec_extras['rdoc_options'] = proc do |rdoc_options|
    rdoc_options << "--title=RubyGems #{self.version} Documentation"
  end

  self.rsync_args += " --no-p -O"

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

# --------------------------------------------------------------------
# Creating a release

task :prerelease => [:clobber, :check_manifest, :test]

task :postrelease => [:publish_docs, :upload]

pkg_dir_path = "pkg/rubygems-update-#{hoe.version}"
task :package do
  mv pkg_dir_path, "pkg/rubygems-#{hoe.version}"
  Dir.chdir 'pkg' do
    sh "tar -czf rubygems-#{hoe.version}.tgz rubygems-#{hoe.version}"
    sh "zip -q -r rubygems-#{hoe.version}.zip rubygems-#{hoe.version}"
  end
end

desc "Upload release to rubyforge"
task :upload_to_rubyforge do
  v = hoe.version
  sh "rubyforge add_release rubygems rubygems #{v} pkg/rubygems-update-#{v}.gem"
  sh "rubyforge add_file rubygems rubygems #{v} pkg/rubygems-#{v}.zip"
  sh "rubyforge add_file rubygems rubygems #{v} pkg/rubygems-#{v}.tgz"
end

desc "Upload release to gemcutter S3"
task :upload_to_gemcutter do
  v = hoe.version
  sh "s3cmd put -P pkg/rubygems-update-#{v}.gem pkg/rubygems-#{v}.zip pkg/rubygems-#{v}.tgz s3://production.s3.rubygems.org/rubygems/"
end

desc "Upload release to rubyforge and gemcutter"
task :upload => [:upload_to_rubyforge, :upload_to_gemcutter]

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
  sh "rsync #{rsync_options} test/               #{dir}/test"
end

def diff_with dir
  diff_options = "-urpN --exclude '*svn*' --exclude '*swp' --exclude '*rbc'"
  sh "diff #{diff_options} bin/gem             #{dir}/bin/gem;         true"
  sh "diff #{diff_options} lib/ubygems.rb      #{dir}/lib/ubygems.rb;  true"
  sh "diff #{diff_options} lib/rubygems.rb     #{dir}/lib/rubygems.rb; true"
  sh "diff #{diff_options} lib/rubygems        #{dir}/lib/rubygems;    true"
  sh "diff #{diff_options} lib/rbconfig        #{dir}/lib/rbconfig;    true"
  sh "diff #{diff_options} test/rubygems       #{dir}/test/rubygems;   true"
end

rubinius_dir = ENV['RUBINIUS_PATH'] || '../git.rubini.us/code'
ruby_dir     = ENV['RUBY_PATH']     || '../../svn/ruby/trunk'

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
  rflags << "--no-color" << "--save coverage.info" << "-T" << "--no-html"

  ruby "#{flags.join ' '} #{rcov} #{rflags.join ' '} #{args[:test]}"
end

def changelog_section code
  name = {
    :major   => "major enhancement",
    :minor   => "minor enhancement",
    :bug     => "bug fix",
    :unknown => "unknown",
  }[code]

  changes = $changes[code]
  count = changes.size
  name += "s" if count > 1
  name.sub!(/fixs/, 'fixes')

  return if count < 1

  puts "* #{count} #{name}:"
  puts
  changes.sort.each do |line|
    puts "  * #{line}"
  end
  puts
end

desc "Print the current changelog."
task "git:newchangelog" do
  # This must be in here until rubygems depends on the version of hoe that has
  # git_tags
  # TODO: get this code back into hoe-git
  module Hoe::Git
    module_function :git_tags, :git_svn?, :git_release_tag_prefix
  end

  tags  = Hoe::Git.git_tags
  tag   = ENV["FROM"] || tags.last
  range = [tag, "HEAD"].compact.join ".."
  cmd   = "git log #{range} '--format=tformat:%B|||%aN|||%aE|||'"
  now   = Time.new.strftime "%Y-%m-%d"

  changes = `#{cmd}`.split(/\|\|\|/).each_slice(3).map do |msg, author, email|
    c = msg.split(/\n/).reject { |s| s.empty? }
    c.empty? ? nil : c.first
  end

  changes = changes.flatten.compact

  next if changes.empty?

  $changes = Hash.new { |h,k| h[k] = [] }

  codes = {
    "!" => :major,
    "+" => :minor,
    "*" => :minor,
    "-" => :bug,
    "?" => :unknown,
  }

  codes_re = Regexp.escape codes.keys.join

  changes.each do |change|
    if change =~ /^\s*([#{codes_re}])\s*(.*)/ then
      code, line = codes[$1], $2
    else
      code, line = codes["?"], change.chomp
    end

    $changes[code] << line
  end

  puts "=== #{ENV['VERSION'] || 'NEXT'} / #{now}"
  puts
  changelog_section :major
  changelog_section :minor
  changelog_section :bug
  changelog_section :unknown
  puts
end
