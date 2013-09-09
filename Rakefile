# -*- ruby -*-

require 'rubygems'
require 'rubygems/package_task'

# HACK bootstrap load_yaml, remove after 1.5 release
def Gem.load_yaml; end unless Gem.respond_to? :load_yaml

if ENV['YAML'] == "syck"
  ENV['TEST_SYCK'] = "1"
end

begin
  require 'psych'
rescue ::LoadError
  require 'yaml'
end

require 'hoe'

Hoe::RUBY_FLAGS << " --disable-gems" if RUBY_VERSION > "1.9"

Hoe.plugin :minitest
Hoe.plugin :git
Hoe.plugin :travis

hoe = Hoe.spec 'rubygems-update' do
  self.author         = ['Jim Weirich', 'Chad Fowler', 'Eric Hodel']
  self.email          = %w[rubygems-developers@rubyforge.org]
  self.readme_file    = 'README.rdoc'

  license 'Ruby'
  license 'MIT'

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

  dependency 'builder',       '~> 2.1',   :dev
  dependency 'hoe-seattlerb', '~> 1.2',   :dev
  dependency 'rdoc',          '~> 3.0',   :dev
  dependency 'ZenTest',       '~> 4.5',   :dev
  dependency 'rake',          '~> 0.9.3', :dev
  dependency 'minitest',      '~> 4.0',   :dev

  self.extra_rdoc_files = Dir["*.rdoc"] + %w[
    CVE-2013-4287.txt
  ]

  spec_extras['rdoc_options'] = proc do |rdoc_options|
    rdoc_options << "--title=RubyGems Update Documentation"
  end

  self.rsync_args += " --no-p -O"

  spec_extras['require_paths'] = %w[hide_lib_for_update]
end

hoe.test_prelude = 'gem "minitest", "~> 4.0"'

Rake::Task['docs'].clear
Rake::Task['clobber_docs'].clear

begin
  require 'rdoc/task'

  RDoc::Task.new :rdoc => 'docs', :clobber_rdoc => 'clobber_docs' do |doc|
    doc.main   = hoe.readme_file
    doc.title  = "RubyGems #{hoe.version} API Documentation"

    rdoc_files = Rake::FileList.new %w[lib History.txt LICENSE.txt MIT.txt]
    rdoc_files.add hoe.extra_rdoc_files

    doc.rdoc_files = rdoc_files

    doc.rdoc_dir = 'doc'
  end
rescue LoadError, RuntimeError # rake 10.1 on rdoc from ruby 1.9.2 and earlier
  task 'docs' do
    abort 'You must install rdoc to build documentation, try `rake newb` again'
  end
end

task :clean_env do
  ENV.delete "GEM_HOME"
  ENV.delete "GEM_PATH"
end

task :test => :clean_env

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
  rsync_options =
    "-avP " +
    "--exclude '*svn*' " +
    "--exclude '*swp' " +
    "--exclude '*rbc' " +
    "--exclude '*.rej' " +
    "--exclude '*.orig' " +
    "--exclude 'lib/rubygems/defaults/*' " +
    "--exclude gauntlet_rubygems.rb"

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
  sh "diff #{diff_options} test                #{dir}/test/rubygems;   true"
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
    msg.split(/\n/).reject { |s| s.empty? }
  end

  changes = changes.flatten

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

desc "Cleanup trailing whitespace"
task :whitespace do
  system 'find . -not \( -name .svn -prune -o -name .git -prune \) -type f -print0 | xargs -0 sed -i "" -E "s/[[:space:]]*$//"'
end
