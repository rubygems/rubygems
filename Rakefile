# -*- ruby -*-

require 'rubygems'
require 'rubygems/package_task'
require "rake/testtask"

if ENV['YAML'] == "syck"
  ENV['TEST_SYCK'] = "1"
end

begin
  require 'psych'
rescue ::LoadError
  require 'yaml'
end

task :setup do
  # TODO: I am sorry for this abomination, and it needs to be replaced. -@duckinator
  gemspec = eval(File.read(File.expand_path("../rubygems-update.gemspec", __FILE__)))
  deps = gemspec.dependencies.map { |dep| [dep.name, dep.requirement.to_s] }

  deps.each do |(name, version)|
    sh "gem install #{name} -v '#{version}'"
  end
end

Rake::TestTask.new do |t|
  # For old rubygems with default bundler gemspec
  if "1.8" < RUBY_VERSION && RUBY_VERSION < "2.2"
    module Gem
      @path_to_default_spec_map.delete_if do |_path, spec|
        spec.name == "bundler"
      end
    end
  end

  # For ruby < 2.0, minitest files need to copied into repo lib folder
  if RUBY_VERSION < '2.0'
    require 'fileutils'
    dest = File.dirname(__FILE__)
    src_dir = Dir.glob("#{Gem.default_dir}/gems/minitest-*").sort
    if (src = src_dir.last)
      Dir.mkdir "#{dest}/lib/minitest" unless Dir.exist? "#{dest}/lib/minitest"
      IO.copy_stream "#{src}/lib/minitest.rb", "#{dest}/lib/minitest.rb"
      FileUtils.cp_r "#{src}/lib/minitest/.", "#{dest}/lib/minitest/"
    end
  end

  # no --disable-gems option
  if RUBY_VERSION < "1.9"
    t.ruby_opts = %w[-I"bundler/lib" -r./lib/rubygems]
  else
    t.ruby_opts = %w[--disable-gems]
  end
  t.ruby_opts << '-rdevkit' if Gem.win_platform?

  t.libs << "test"
  t.libs << "bundler/lib" if RUBY_VERSION >= "2.5"
  t.test_files = FileList['test/**/test_*.rb']
end

v = "2.7.4"

begin
  gem 'rdoc', '~> 4.0'
  require 'rdoc/task'

  RDoc::Task.new :rdoc => 'docs', :clobber_rdoc => 'clobber_docs' do |doc|
    doc.main   = 'README.md'
    doc.title  = "RubyGems #{v} API Documentation"

    rdoc_files = Rake::FileList.new %w[lib History.txt LICENSE.txt MIT.txt]
    rdoc_files.add ["CODE_OF_CONDUCT.md".freeze, "CONTRIBUTING.rdoc".freeze, "CVE-2013-4287.txt".freeze, "CVE-2013-4363.txt".freeze, "CVE-2015-3900.txt".freeze, "History.txt".freeze, "LICENSE.txt".freeze, "MAINTAINERS.txt".freeze, "MIT.txt".freeze, "Manifest.txt".freeze, "POLICIES.rdoc".freeze, "README.md".freeze, "UPGRADING.rdoc".freeze, "bundler/CHANGELOG.md".freeze, "bundler/CODE_OF_CONDUCT.md".freeze, "bundler/CONTRIBUTING.md".freeze, "bundler/LICENSE.md".freeze, "bundler/README.md".freeze, "hide_lib_for_update/note.txt".freeze, "CONTRIBUTING.rdoc".freeze, "POLICIES.rdoc".freeze, "UPGRADING.rdoc".freeze, "CVE-2013-4287.txt".freeze, "CVE-2013-4363.txt".freeze]

    doc.rdoc_files = rdoc_files

    doc.rdoc_dir = 'doc'
  end
rescue LoadError, RuntimeError # rake 10.1 on rdoc from ruby 1.9.2 and earlier
  task 'docs' do
    abort 'You must install rdoc to build documentation, try `rake newb` again'
  end
end

desc "Install gems needed to run the tests"
task :install_test_deps => :clean do
  sh "gem install minitest -v '~> 5.0'"
end

begin
  require "automatiek"

  Automatiek::RakeTask.new("molinillo") do |lib|
    lib.download = { :github => "https://github.com/CocoaPods/Molinillo" }
    lib.namespace = "Molinillo"
    lib.prefix = "Gem::Resolver"
    lib.vendor_lib = "lib/rubygems/resolver/molinillo"
  end
rescue LoadError
  namespace :vendor do
    task(:molinillo) { abort "Install the automatiek gem to be able to vendor gems." }
  end
end

# --------------------------------------------------------------------
# Creating a release

task :prerelease => [:clobber, :check_manifest, :test]

task :postrelease => %w[upload guides:publish blog:publish]

file "pkg/rubygems-update-#{v}" do
  require 'fileutils'
  `gem build rubygems-update.gemspec`
  `gem unpack rubygems-update-#{v}.gem`
  FileUtils.mv "rubygems-update-#{v}.gem", "pkg"
  FileUtils.rm_rf "pkg/rubygems-update-#{v}"
  FileUtils.mv "rubygems-update-#{v}", "pkg"
end

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

desc "Upload release to S3"
task :upload_to_s3 do
  sh "s3cmd put -P pkg/rubygems-#{v}.zip pkg/rubygems-#{v}.tgz s3://oregon.production.s3.rubygems.org/rubygems/"
end

desc "Upload release to rubygems.org"
task :upload => %w[upload_to_s3]

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

  on_master = `git branch --list master`.strip == '* master'
  on_master = true if ENV['FORCE']

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

      sh(ENV['EDITOR'] || 'vim', io.path)

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

desc "Cleanup trailing whitespace"
task :whitespace do
  system 'find . -not \( -name .svn -prune -o -name .git -prune \) -type f -print0 | xargs -0 sed -i "" -E "s/[[:space:]]*$//"'
end

desc "Update the manifest to reflect what's on disk"
task :update_manifest do
  files = []
  require 'find'
  exclude = %r[/\/tmp\/|pkg|CVS|\.svn|\.git|TAGS|extconf.h|\.bundle$|\.o$|\.log$/|\./bundler/(?!lib|man|exe|[^/]+\.md|bundler.gemspec)|doc/]ox
  Find.find(".") do |path|
    next unless File.file?(path)
    next if path =~ exclude
    files << path[2..-1]
  end
  File.open('Manifest.txt', 'w') {|f| f.puts(files.sort) }
end

namespace :bundler do
  task :checkout do
    sh "git submodule update --init"
  end
end
