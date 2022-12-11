RakeFileUtils.verbose_flag = false

require "rubygems"
require "rubygems/package_task"
require "rake/testtask"

module RubyGems
  module DevTasks
    include FileUtils

    extend self

    def bundle_dev_gemfile(*args)
      sh "ruby", "-I", "lib", "bundler/spec/support/bundle.rb", *args, "--gemfile=bundler/tool/bundler/dev_gems.rb"
    end

    def bundle_support_gemfile(name, *args)
      sh "ruby", "-I", "lib", "bundler/spec/support/bundle.rb", *args, "--gemfile=bundler/tool/bundler/#{name}.rb"
    end
  end
end

desc "Setup Rubygems dev environment"
task :setup do
  RubyGems::DevTasks.bundle_dev_gemfile "install"
  RubyGems::DevTasks.bundle_support_gemfile "release_gems","lock"
  RubyGems::DevTasks.bundle_support_gemfile "test_gems", "lock"
  RubyGems::DevTasks.bundle_support_gemfile "rubocop_gems", "lock"
  RubyGems::DevTasks.bundle_support_gemfile "standard_gems", "lock"
end

desc "Update Rubygems dev environment"
task :update do
  RubyGems::DevTasks.bundle_dev_gemfile "update"
  RubyGems::DevTasks.bundle_support_gemfile "release_gems", "lock", "--update"
  RubyGems::DevTasks.bundle_support_gemfile "test_gems", "lock", "--update"
  RubyGems::DevTasks.bundle_support_gemfile "rubocop_gems", "lock", "--update"
  RubyGems::DevTasks.bundle_support_gemfile "standard_gems", "lock", "--update"
end

desc "Update the locked bundler version in dev environment"
task :update_locked_bundler do |_, args|
  RubyGems::DevTasks.bundle_support_gemfile "dev_gems", "update", "--bundler"
  RubyGems::DevTasks.bundle_support_gemfile "release_gems", "update", "--bundler"
  RubyGems::DevTasks.bundle_support_gemfile "test_gems", "update", "--bundler"
  RubyGems::DevTasks.bundle_support_gemfile "rubocop_gems", "update", "--bundler"
  RubyGems::DevTasks.bundle_support_gemfile "standard_gems", "update", "--bundler"
end

desc "Update specific development dependencies"
task :update_dev_dep do |_, args|
  RubyGems::DevTasks.bundle_dev_gemfile "update", *args
end

desc "Update RSpec related gems"
task :update_rspec_deps do |_, args|
  RubyGems::DevTasks.bundle_dev_gemfile "update", "rspec-core", "rspec-expectations", "rspec-mocks"
  RubyGems::DevTasks.bundle_support_gemfile "rubocop_gems", "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks"
  RubyGems::DevTasks.bundle_support_gemfile "rubocop23_gems", "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks"
  RubyGems::DevTasks.bundle_support_gemfile "rubocop24_gems", "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks"
  RubyGems::DevTasks.bundle_support_gemfile "standard_gems", "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks"
  RubyGems::DevTasks.bundle_support_gemfile "standard23_gems", "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks"
  RubyGems::DevTasks.bundle_support_gemfile "standard24_gems", "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks"
end

desc "Setup git hooks"
task :git_hooks do
  sh "git config core.hooksPath .githooks"
end

Rake::TestTask.new do |t|
  t.ruby_opts = %w[-w]
  t.ruby_opts << "-rdevkit" if RbConfig::CONFIG["host_os"].include?("mingw")

  t.libs << "test"
  t.libs << "bundler/lib"

  t.test_files = FileList["test/**/test_*.rb"]
end

namespace "test" do
  desc "Run each test isolatedly by specifying the relative test file path"
  task "isolated" do
    FileList["test/**/test_*.rb"].each do |file|
      sh Gem.ruby, "-Ilib:test:bundler/lib", file
    end
  end
end

task :default => :test

spec = Gem::Specification.load("rubygems-update.gemspec")
v = spec.version

require "rdoc/task"

RDoc::Task.new :rdoc => "docs", :clobber_rdoc => "clobber_docs" do |doc|
  doc.main   = "README.md"
  doc.title  = "RubyGems #{v} API Documentation"

  rdoc_files = Rake::FileList.new %w[lib bundler/lib]
  rdoc_files.add %w[CHANGELOG.md LICENSE.txt MIT.txt CODE_OF_CONDUCT.md CONTRIBUTING.md
                    MAINTAINERS.txt Manifest.txt POLICIES.md README.md UPGRADING.md bundler/CHANGELOG.md
                    bundler/doc/contributing/README.md bundler/LICENSE.md bundler/README.md
                    hide_lib_for_update/note.txt].map(&:freeze)

  doc.rdoc_files = rdoc_files

  doc.rdoc_dir = "doc"
end

# No big deal if Automatiek is not available. This might be just because
# `rake` is executed from release tarball.
if File.exist?("util/automatiek.rake")
  load "util/automatiek.rake"

  # We currently ship Molinillo master branch as of
  # https://github.com/CocoaPods/Molinillo/commit/7cc27a355e861bdf593e2cde7bf1bca3daae4303
  Automatiek::RakeTask.new("molinillo") do |lib|
    lib.version = "master"
    lib.download = { :github => "https://github.com/CocoaPods/Molinillo" }
    lib.namespace = "Molinillo"
    lib.prefix = "Gem::Resolver"
    lib.vendor_lib = "lib/rubygems/resolver/molinillo"
    lib.license_path = "LICENSE"

    lib.dependency("tsort") do |sublib|
      sublib.version = "v0.1.1"
      sublib.download = { :github => "https://github.com/ruby/tsort" }
      sublib.namespace = "TSort"
      sublib.prefix = "Gem"
      sublib.vendor_lib = "lib/rubygems/tsort"
      sublib.license_path = "LICENSE.txt"
    end
  end

  # We currently ship optparse 0.3.0 plus the following changes:
  # * Remove top aliasing the `::OptParse` constant to `OptionParser`, since we
  #   don't need it and it triggers redefinition warnings since the default
  #   optparse gem also does the aliasing.
  # * Add an empty .document file to the library's root path to hint RDoc that
  #   this library should not be documented.
  desc "Vendor a specific version of optparse"
  Automatiek::RakeTask.new("optparse") do |lib|
    lib.version = "v0.3.0"
    lib.download = { :github => "https://github.com/ruby/optparse" }
    lib.namespace = "OptionParser"
    lib.prefix = "Gem"
    lib.vendor_lib = "lib/rubygems/optparse"
    lib.license_path = "COPYING"
  end
end

namespace :rubocop do
  desc "Setup gems necessary to lint Ruby code"
  task(:setup) do
    sh "ruby", "-I", "lib", "bundler/spec/support/bundle.rb", "install", "--gemfile=bundler/tool/bundler/lint_gems.rb"
  end

  desc "Run rubocop for RubyGems. Pass positional arguments, e.g. -a, as Rake arguments."
  task(:rubygems) do |_, args|
    sh "util/rubocop", *args
  end

  desc "Run rubocop for Bundler. Pass positional arguments, e.g. -a, as Rake arguments."
  task(:bundler) do |_, args|
    sh "bundler/bin/rubocop", *args
  end
end

task rubocop: %w[rubocop:setup rubocop:rubygems rubocop:bundler]

# --------------------------------------------------------------------
# Creating a release

task :prerelease => %w[clobber install_release_dependencies test bundler:build_metadata check_deprecations]
task :postrelease => %w[upload guides:publish blog:publish bundler:build_metadata:clean]

desc "Check for deprecated methods with expired deprecation horizon"
task :check_deprecations do
  if v.segments[1] == 0 && v.segments[2] == 0
    sh("util/rubocop -r ./util/cops/deprecations --only Rubygems/Deprecations")
  else
    puts "Skipping deprecation checks since not releasing a major version."
  end
end

desc "Install release dependencies"
task :install_release_dependencies do
  require_relative "util/release"

  Release.install_dependencies!
end

desc "Prepare a release"
task :prepare_release, [:version] => [:install_release_dependencies] do |_t, opts|
  require_relative "util/release"

  Release.new(opts[:version] || v.to_s).prepare!
end

desc "Install rubygems to local system"
task :install => [:clear_package, :package] do
  sh "ruby -Ilib bin/gem install --no-document pkg/rubygems-update-#{v}.gem --backtrace && update_rubygems --no-document --backtrace"
end

desc "Clears previously built package"
task :clear_package do
  rm_rf "pkg"
end

desc "Generates the changelog for a specific target version"
task :generate_changelog, [:version] do |_t, opts|
  require_relative "util/release"

  Release.for_rubygems(opts[:version]).cut_changelog!
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
  require "find"

  dest_root = File.expand_path t.name

  cd t.source do
    Find.find "." do |file|
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
  cd "pkg" do
    if Gem.win_platform?
      sh "7z a rubygems-#{v}.zip rubygems-#{v}"
    else
      sh "zip -q -r rubygems-#{v}.zip rubygems-#{v}"
    end
  end
end

file "pkg/rubygems-#{v}.tgz" => "pkg/rubygems-#{v}" do
  cd "pkg" do
    tar_version = `tar --version`
    if tar_version.include?("bsdtar")
      # bsdtar, as used by at least FreeBSD and macOS, uses `--uname` and `--gname`.
      sh "tar -czf rubygems-#{v}.tgz --uname=rubygems:0 --gname=rubygems:0 rubygems-#{v}"
    else # If a third variant is added, change this line to: elsif tar_version =~ /GNU tar/
      # GNU Tar, as used by many Linux distros, uses `--owner` and `--group`.
      sh "tar -czf rubygems-#{v}.tgz --owner=rubygems:0 --group=rubygems:0 rubygems-#{v}"
    end
  end
end

desc "Upload the release to GitHub releases"
task :upload_to_github do
  require_relative "util/release"

  Release.for_rubygems(v).create_for_github!
end

desc "Upload release to S3"
task :upload_to_s3 do
  require "aws-sdk-s3"

  s3 = Aws::S3::Resource.new(region:"us-west-2")
  %w[zip tgz].each do |ext|
    obj = s3.bucket("oregon.production.s3.rubygems.org").object("rubygems/rubygems-#{v}.#{ext}")
    obj.upload_file("pkg/rubygems-#{v}.#{ext}", acl: "public-read")
  end
end

desc "Upload release to rubygems.org"
task :upload => %w[upload_to_github upload_to_s3]

directory "../guides.rubygems.org" do
  sh "git", "clone",
     "https://github.com/rubygems/guides.git",
     "../guides.rubygems.org"
end

namespace "guides" do
  task "pull" => %w[../guides.rubygems.org] do
    chdir "../guides.rubygems.org" do
      sh "git", "pull"
    end
  end

  task "update" => %w[../guides.rubygems.org] do
    lib_dir = File.join Dir.pwd, "lib"

    chdir "../guides.rubygems.org" do
      ruby "-I", lib_dir, "-S", "rake", "command_guide"
      ruby "-I", lib_dir, "-S", "rake", "spec_guide"
    end
  end

  task "commit" => %w[../guides.rubygems.org] do
    chdir "../guides.rubygems.org" do
      begin
        sh "git", "diff", "--quiet"
      rescue
        sh "git", "commit", "command-reference.md", "specification-reference.md",
           "-m", "Rebuild for RubyGems #{v}"
      end
    end
  end

  task "push" => %w[../guides.rubygems.org] do
    chdir "../guides.rubygems.org" do
      sh "git", "push"
    end
  end

  desc "Updates and publishes the guides for the just-released RubyGems"
  task "publish"

  task "publish" => %w[
    guides:pull
    guides:update
    guides:commit
    guides:push
  ]
end

directory "../blog.rubygems.org" do
  sh "git", "clone",
    "https://github.com/rubygems/rubygems.github.io.git",
     "../blog.rubygems.org"
end

namespace "blog" do
  date = Time.now.strftime "%Y-%m-%d"
  post_page = "_posts/#{date}-#{v}-released.md"
  checksums = ""

  task "checksums" => "package" do
    require "net/http"
    Dir["pkg/*{tgz,zip,gem}"].each do |file|
      digest = OpenSSL::Digest::SHA256.file(file).hexdigest
      basename = File.basename(file)

      checksums << "* #{basename}  \n"
      checksums << "  #{digest}\n"

      release_url = URI("https://rubygems.org/#{file.end_with?("gem") ? "gems" : "rubygems"}/#{basename}")
      response = Net::HTTP.get_response(release_url)

      if response.is_a?(Net::HTTPSuccess)
        released_digest = OpenSSL::Digest::SHA256.hexdigest(response.body)

        if digest != released_digest
          abort "Checksum of #{file} (#{digest}) doesn't match checksum of released package at #{release_url} (#{released_digest})"
        end
      elsif response.is_a?(Net::HTTPForbidden)
        abort "#{basename} has not been yet uploaded to rubygems.org"
      else
        abort "Error fetching released package to verify checksums: #{response}\n#{response.body}"
      end
    end
  end

  task "pull" => %w[../blog.rubygems.org] do
    chdir "../blog.rubygems.org" do
      sh "git", "pull"
    end
  end

  path = File.join "../blog.rubygems.org", post_page

  task "update" => [path]

  file path => "checksums" do
    name  = `git config --get user.name`.strip
    email = `git config --get user.email`.strip

    require_relative "util/changelog"
    history = Changelog.for_rubygems(v.to_s)

    require "tempfile"

    Tempfile.open "blog_post" do |io|
      io.write <<-ANNOUNCEMENT
---
title: #{v} Released
layout: post
author: #{name}
author_email: #{email}
---

RubyGems #{v} includes #{history.change_types_for_blog}.

To update to the latest RubyGems you can run:

    gem update --system

To install RubyGems by hand see the [Download RubyGems][download] page.

#{history.release_notes_for_blog.join("\n")}

SHA256 Checksums:

#{checksums}

[download]: https://rubygems.org/pages/download

      ANNOUNCEMENT

      io.flush

      sh(ENV["EDITOR"] || "vim", io.path)

      FileUtils.cp io.path, path
    end
  end

  task "commit" => %w[../blog.rubygems.org] do
    chdir "../blog.rubygems.org" do
      sh "git", "add", post_page
      sh "git", "commit", post_page,
         "-m", "Added #{v} release announcement"
    end
  end

  task "push" => %w[../blog.rubygems.org] do
    chdir "../blog.rubygems.org" do
      sh "git", "push"
    end
  end

  desc "Updates and publishes the blog for the just-released RubyGems"
  task "publish" => %w[
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
      exclude = %r{\A(?:\.|bundler/(?!lib|exe|[^/]+\.md|bundler.gemspec)|util/|Rakefile)}
      tracked_files = `git ls-files`.split("\n")

      tracked_files.each do |path|
        next unless File.file?(path)
        next if path =~ exclude
        files << path
      end

      files.sort
    end
  end
end

desc "Update the manifest to reflect what's on disk"
task :update_manifest do
  File.open("Manifest.txt", "w") {|f| f.puts(Rubygems::ProjectFiles.all) }
end

desc "Check the manifest is up to date"
task :check_manifest do
  if File.read("Manifest.txt").split != Rubygems::ProjectFiles.all
    abort "Manifest is out of date. Run `rake update_manifest` to sync it"
  end
end

desc "Update License list from SPDX.org"
task :update_licenses do
  load "util/generate_spdx_license_list.rb"
end

namespace :bundler do
  task :build_metadata do
    chdir("bundler") { sh "rake build_metadata" }
  end

  namespace :build_metadata do
    task :clean do
      chdir("bundler") { sh "rake build_metadata:clean" }
    end
  end
end
