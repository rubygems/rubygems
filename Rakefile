# -*- ruby -*-

require 'rubygems'
require 'rubygems/package_task'

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

  dependency 'builder',       '~> 2.1',   :dev
  dependency 'hoe-seattlerb', '~> 1.2',   :dev
  dependency 'rdoc',          '~> 3.0',   :dev
  dependency 'ZenTest',       '~> 4.5',   :dev
  dependency 'rake',          '~> 0.9.3', :dev
  dependency 'minitest',      '~> 4.0',   :dev

  self.extra_rdoc_files = Dir["*.rdoc"] + %w[
    CVE-2013-4287.txt
    CVE-2013-4363.txt
  ]

  spec_extras['rdoc_options'] = proc do |rdoc_options|
    rdoc_options << "--title=RubyGems Update Documentation"
  end

  self.rsync_args += " --no-p -O"

  spec_extras['require_paths'] = %w[hide_lib_for_update]
end

v = hoe.version

hoe.test_prelude = 'gem "minitest", "~> 4.0"'

Rake::Task['docs'].clear
Rake::Task['clobber_docs'].clear

begin
  require 'rdoc/task'

  RDoc::Task.new :rdoc => 'docs', :clobber_rdoc => 'clobber_docs' do |doc|
    doc.main   = hoe.readme_file
    doc.title  = "RubyGems #{v} API Documentation"

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

desc "Install gems needed to run the tests"
task :install_test_deps => :clean_env do
  sh "gem install minitest -v '~> 4.0'"
end

# --------------------------------------------------------------------
# Creating a release

task :prerelease => [:clobber, :check_manifest, :test]

task :postrelease => %w[upload guides:publish blog:publish publish_docs]

file "pkg/rubygems-#{v}" => "pkg/rubygems-update-#{v}" do |t|
  require 'find'

  dest_root = File.expand_path t.name

  cd t.source do
    Find.find '.' do |file|
      dest = File.expand_path file, dest_root

      if File.directory? file then
        mkdir_p dest
      else
        rm_f dest
        safe_ln file, dest
      end
    end
  end
end

source_pkg_dir = "pkg/rubygems-#{v}"

file "pkg/rubygems-#{v}.tgz" => source_pkg_dir do
  cd 'pkg' do
    sh "tar -czf rubygems-#{v}.tgz rubygems-#{v}"
  end
end

file "pkg/rubygems-#{v}.zip" => source_pkg_dir do
  cd 'pkg' do
    sh "zip -q -r rubygems-#{v}.zip rubygems-#{v}"
  end
end

file "pkg/rubygems-update-#{v}.gem"

task :package => %W[
       pkg/rubygems-update-#{v}.gem
       pkg/rubygems-#{v}.tgz
       pkg/rubygems-#{v}.zip
     ]

desc "Upload release to gemcutter S3"
task :upload_to_gemcutter do
  sh "s3cmd put -P pkg/rubygems-update-#{v}.gem pkg/rubygems-#{v}.zip pkg/rubygems-#{v}.tgz s3://production.s3.rubygems.org/rubygems/"
end

desc "Upload release to rubygems.org"
task :upload => %w[upload_to_gemcutter]

on_master = `git branch --list master`.strip == '* master'
on_master = true if ENV['FORCE']

Rake::Task['publish_docs'].clear unless on_master

directory '../guides.rubygems.org' do
  sh 'git', 'clone',
     'git@github.com:rubygems/guides.git',
     '../guides.rubygems.org'
end

namespace 'guides' do
  task 'pull' => %w[../guides.rubygems.org] do
    chdir '../guides.rubygems.org' do
      sh 'git', 'pull'
    end
  end

  task 'update' => %w[../guides.rubygems.org] do
    lib_dir = File.join Dir.pwd, 'lib'

    chdir '../guides.rubygems.org' do
      ruby '-I', lib_dir, '-S', 'rake', 'command_guide'
      ruby '-I', lib_dir, '-S', 'rake', 'spec_guide'
    end
  end

  task 'commit' => %w[../guides.rubygems.org] do
    chdir '../guides.rubygems.org' do
      begin
        sh 'git', 'diff', '--quiet'
      rescue
        sh 'git', 'commit', 'command-reference.md', 'specification-reference.md',
           '-m', "Rebuild for RubyGems #{v}"
      end
    end
  end

  task 'push' => %w[../guides.rubygems.org] do
    chdir '../guides.rubygems.org' do
      sh 'git', 'push'
    end
  end

  desc 'Updates and publishes the guides for the just-released RubyGems'
  task 'publish'

  task 'publish' => %w[
    guides:pull
    guides:update
    guides:commit
    guides:push
  ] if on_master
end

directory '../blog.rubygems.org' do
  sh 'git', 'clone',
     'git@github.com:rubygems/rubygems.github.com.git',
     '../blog.rubygems.org'
end

namespace 'blog' do
  date = Time.now.strftime '%Y-%m-%d'
  post_page = "_posts/#{date}-#{v}-released.md"
  checksums = ''

  task 'checksums' => 'package' do
    require 'digest'
    Dir['pkg/*{tgz,zip,gem}'].map do |file|
      digest = Digest::SHA256.new

      open file, 'rb' do |io|
        while chunk = io.read(65536) do
          digest.update chunk
        end
      end

      checksums << "* #{File.basename(file)}  \n"
      checksums << "  #{digest.hexdigest}\n"
    end
  end

  task 'pull' => %w[../blog.rubygems.org] do
    chdir '../blog.rubygems.org' do
      sh 'git', 'pull'
    end
  end

  path = File.join '../blog.rubygems.org', post_page

  task 'update' => [path]

  file path => 'checksums' do
    name  = `git config --get user.name`.strip
    email = `git config --get user.email`.strip

    history = File.read 'History.txt'

    history.force_encoding Encoding::UTF_8 if Object.const_defined? :Encoding

    _, change_log, = history.split %r%^===\s*\d.*%, 3

    change_types = []

    lines = change_log.strip.lines
    change_log = []

    while line = lines.shift do
      case line
      when /(^[A-Z].*)/ then
        change_types << $1
        change_log << "_#{$1}_\n"
      when /^\*/ then
        entry = [line.strip]

        while /^  \S/ =~ lines.first do
          entry << lines.shift.strip
        end

        change_log << "#{entry.join ' '}\n"
      else
        change_log << line
      end
    end

    change_log = change_log.join

    change_types = change_types.map do |change_type|
      change_type.downcase.tr '^a-z ', ''
    end

    last_change_type = change_types.pop

    if change_types.empty? then
      change_types = ''
    else
      change_types = change_types.join(', ') << ' and '
    end

    change_types << last_change_type

    require 'tempfile'

    Tempfile.open 'blog_post' do |io|
      io.write <<-ANNOUNCEMENT
---
title: #{v} Released
layout: post
author: #{name}
author_email: #{email}
---

RubyGems #{v} includes #{change_types}.

To update to the latest RubyGems you can run:

    gem update --system

If you need to upgrade or downgrade please follow the [how to upgrade/downgrade
RubyGems][upgrading] instructions.  To install RubyGems by hand see the
[Download RubyGems][download] page.

#{change_log}

SHA256 Checksums:

#{checksums}

[download]: http://rubygems.org/pages/download
[upgrading]: http://docs.seattlerb.org/rubygems/UPGRADING_rdoc.html

      ANNOUNCEMENT

      io.flush

      sh ENV['EDITOR'], io.path

      FileUtils.cp io.path, path
    end
  end

  task 'commit' => %w[../blog.rubygems.org] do
    chdir '../blog.rubygems.org' do
      sh 'git', 'add', post_page
      sh 'git', 'commit', post_page,
         '-m', "Added #{v} release announcement"
    end
  end

  task 'push' => %w[../blog.rubygems.org] do
    chdir '../blog.rubygems.org' do
      sh 'git', 'push'
    end
  end

  desc 'Updates and publishes the blog for the just-released RubyGems'
  task 'publish' => %w[
    blog:pull
    blog:update
    blog:commit
    blog:push
  ]
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

desc "Cleanup trailing whitespace"
task :whitespace do
  system 'find . -not \( -name .svn -prune -o -name .git -prune \) -type f -print0 | xargs -0 sed -i "" -E "s/[[:space:]]*$//"'
end
