# -*- ruby -*-

require 'rubygems'
require 'rubygems/package_task'
require "rake/testtask"
require 'psych'

desc "Setup Rubygems dev environment"
task :setup => ["bundler:checkout"] do
  sh "gem install bundler:2.0.2"
  sh "bundle install"
end

desc "Setup git hooks"
task :git_hooks do
  sh "git config core.hooksPath .githooks"
end

Rake::TestTask.new do |t|
  t.ruby_opts = %w[-w]
  t.ruby_opts << '-rdevkit' if Gem.win_platform?

  t.libs << "test"
  t.libs << "bundler/lib"

  t.test_files = FileList['test/**/test_*.rb']
end

task :default => :test

spec = Gem::Specification.load('rubygems-update.gemspec')
v = spec.version

require 'rdoc/task'

RDoc::Task.new :rdoc => 'docs', :clobber_rdoc => 'clobber_docs' do |doc|
  doc.main   = 'README.md'
  doc.title  = "RubyGems #{v} API Documentation"

  rdoc_files = Rake::FileList.new %w[lib bundler/lib]
  rdoc_files.add %w[History.txt LICENSE.txt MIT.txt CODE_OF_CONDUCT.md CONTRIBUTING.rdoc
                    MAINTAINERS.txt Manifest.txt POLICIES.rdoc README.md UPGRADING.rdoc bundler/CHANGELOG.md
                    bundler/CODE_OF_CONDUCT.md bundler/CONTRIBUTING.md bundler/LICENSE.md bundler/README.md
                    hide_lib_for_update/note.txt].map(&:freeze)

  doc.rdoc_files = rdoc_files

  doc.rdoc_dir = 'doc'
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

desc "Run rubocop"
task(:rubocop) do
  sh "util/rubocop"
end

desc "Run a test suite bisection"
task(:bisect) do
  seed = begin
           Integer(ENV["SEED"])
         rescue
           abort "Specify the failing seed as the SEED environment variable"
         end

  gemdir = `gem env gemdir`.chomp
  sh "SEED=#{seed} MTB_VERBOSE=2 util/bisect -Ilib:bundler/lib:test:#{gemdir}/gems/minitest-server-1.0.5/lib test"
end

# --------------------------------------------------------------------
# Creating a release

task :prerelease => %w[clobber test bundler:build_metadata check_deprecations]
task :postrelease => %w[bundler:build_metadata:clean upload guides:publish blog:publish]

desc "Check for deprecated methods with expired deprecation horizon"
task :check_deprecations do
  if v.segments[1] == 0 && v.segments[2] == 0
    sh("util/rubocop -r ./util/cops/deprecations --only Rubygems/Deprecations")
  else
    puts "Skipping deprecation checks since not releasing a major version."
  end
end

desc "Install rubygems to local system"
task :install => [:clear_package, :package] do
  sh "ruby -Ilib bin/gem install pkg/rubygems-update-#{v}.gem && update_rubygems"
end

desc "Clears previously built package"
task :clear_package do
  rm_rf "pkg"
end

desc "Release rubygems-#{v}"
task :release => :prerelease do
  Rake::Task["package"].invoke
  sh "gem push pkg/rubygems-update-#{v}.gem"
  Rake::Task["postrelease"].invoke
end

Gem::PackageTask.new(spec) {}

Rake::Task["package"].enhance ["pkg/rubygems-#{v}.tgz", "pkg/rubygems-#{v}.zip"]

file "pkg/rubygems-#{v}" => "pkg/rubygems-update-#{v}" do |t|
  require 'find'

  dest_root = File.expand_path t.name

  cd t.source do
    Find.find '.' do |file|
      dest = File.expand_path file, dest_root

      if File.directory? file
        mkdir_p dest
      else
        rm_f dest
        safe_ln file, dest
      end
    end
  end
end

file "pkg/rubygems-#{v}.zip" => "pkg/rubygems-#{v}" do
  cd 'pkg' do
    if Gem.win_platform?
      sh "7z a rubygems-#{v}.zip rubygems-#{v}"
    else
      sh "zip -q -r rubygems-#{v}.zip rubygems-#{v}"
    end
  end
end

file "pkg/rubygems-#{v}.tgz" => "pkg/rubygems-#{v}" do
  cd 'pkg' do
    if Gem.win_platform? && RUBY_VERSION < '2.4'
      sh "7z a -ttar  rubygems-#{v}.tar rubygems-#{v}"
      sh "7z a -tgzip rubygems-#{v}.tgz rubygems-#{v}.tar"
    else
      sh "tar -czf rubygems-#{v}.tgz rubygems-#{v}"
    end
  end
end

desc "Upload release to S3"
task :upload_to_s3 do
  begin
    require "aws-sdk-s3"
  rescue LoadError
    abort "Install the aws-sdk-s3 gem to be able to upload gems to rubygems.org."
  end

  s3 = Aws::S3::Resource.new(region:'us-west-2')
  %w[zip tgz].each do |ext|
    obj = s3.bucket('oregon.production.s3.rubygems.org').object("rubygems/rubygems-#{v}.#{ext}")
    obj.upload_file("pkg/rubygems-#{v}.#{ext}", acl: 'public-read')
  end
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

    history.force_encoding Encoding::UTF_8

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

    if change_types.empty?
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

[download]: https://rubygems.org/pages/download
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

module Rubygems
  class ProjectFiles

    def self.all
      files = []
      exclude = %r[\.git|\./bundler/(?!lib|man|exe|[^/]+\.md|bundler.gemspec)]ox
      tracked_files = `git ls-files --recurse-submodules`.split("\n").map {|f| "./#{f}" }

      tracked_files.each do |path|
        next unless File.file?(path)
        next if path =~ exclude
        files << path[2..-1]
      end

      files
    end

  end
end

desc "Update the manifest to reflect what's on disk"
task :update_manifest do
  File.open('Manifest.txt', 'w') {|f| f.puts(Rubygems::ProjectFiles.all.sort) }
end

desc "Check the manifest is up to date"
task :check_manifest do
  if File.read("Manifest.txt").split.sort != Rubygems::ProjectFiles.all.sort
    abort "Manifest is out of date. Run `rake update_manifest` to sync it"
  end
end

namespace :bundler do
  desc "Initialize bundler submodule"
  task :checkout do
    sh "git submodule update --init"
  end

  task :build_metadata do
    chdir('bundler') { sh "rake build_metadata" }
  end

  namespace :build_metadata do
    task :clean do
      chdir('bundler') { sh "rake build_metadata:clean" }
    end
  end
end
