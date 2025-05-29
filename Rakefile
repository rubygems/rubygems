# frozen_string_literal: true

RakeFileUtils.verbose_flag = false

require "rubygems"
require "rubygems/package_task"
require "rake/testtask"

require_relative "bundler/spec/support/rubygems_ext"

desc "Setup Rubygems dev environment"
task setup: [:"dev:deps"] do
  Dir.glob("tool/bundler/*_gems.rb").each do |file|
    name = File.basename(file, ".rb")
    next if name == "dev_gems"
    Spec::Rubygems.dev_bundle "lock", gemfile: file
  end
end

desc "Update Rubygems dev environment"
task :update do
  Spec::Rubygems.dev_bundle "update"
  Dir.glob("tool/bundler/*_gems.rb").each do |file|
    name = File.basename(file, ".rb")
    next if name == "dev_gems"
    Spec::Rubygems.dev_bundle "lock", "--update", gemfile: file
  end
end

namespace :version do
  desc "Update the locked bundler version in dev environment"
  task update_locked_bundler: [:"bundler:install"] do |_, _args|
    stdout = Spec::Rubygems.dev_bundle "--version"
    version = stdout.split(" ").last

    Dir.glob("tool/bundler/*_gems.rb").each do |file|
      Spec::Rubygems.dev_bundle("update", "--bundler", version, gemfile: file)
    end
  end

  desc "Check locked bundler version is up to date"
  task check: :update_locked_bundler do
    Spec::Rubygems.check_source_control_changes(
      success_message: "Locked bundler version is out of sync",
      error_message: "Please run `rake version:update_locked_bundler` and commit the result."
    )
  end
end

desc "Update specific development dependencies"
task :update_dev_dep do |_, args|
  Spec::Rubygems.dev_bundle "update", *args
end

desc "Update RSpec related gems"
task :update_rspec_deps do |_, _args|
  Spec::Rubygems.dev_bundle "update", "rspec-core", "rspec-expectations", "rspec-mocks"
  Spec::Rubygems.dev_bundle "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks", gemfile: "tool/bundler/rubocop_gems.rb"
  Spec::Rubygems.dev_bundle "lock", "--update", "rspec-core", "rspec-expectations", "rspec-mocks", gemfile: "tool/bundler/standard_gems.rb"
end

desc "Setup git hooks"
task :git_hooks do
  sh "git config core.hooksPath .githooks"
end

Rake::TestTask.new do |t|
  t.ruby_opts = %w[-w]
  t.ruby_opts << "-rdevkit" if RbConfig::CONFIG["host_os"].include?("mingw")

  t.libs << "test"
  t.test_files = FileList["test/**/test_*.rb"]
end

namespace "test" do
  desc "Run each test isolatedly by specifying the relative test file path"
  task "isolated" do
    FileList["test/**/{bundler_,}test_*.rb"].each do |file|
      sh Gem.ruby, "-Ilib:test:bundler/lib", file
    end
  end
end

task default: [:test, :spec]

spec = Gem::Specification.load(File.expand_path("rubygems-update.gemspec", __dir__))
v = spec.version

require "rdoc/task"

RDoc::Task.new rdoc: "docs", clobber_rdoc: "clobber_docs" do |doc|
  doc.main   = "README.md"
  doc.title  = "RubyGems #{v} API Documentation"

  rdoc_files = Rake::FileList.new %w[lib bundler/lib]
  rdoc_files.add %w[CHANGELOG.md LICENSE.txt MIT.txt CODE_OF_CONDUCT.md doc/rubygems/CONTRIBUTING.md
                    doc/MAINTAINERS.txt Manifest.txt doc/rubygems/POLICIES.md README.md doc/rubygems/UPGRADING.md bundler/CHANGELOG.md
                    doc/bundler/contributing/README.md bundler/LICENSE.md bundler/README.md
                    hide_lib_for_update/note.txt].map(&:freeze)

  doc.rdoc_files = rdoc_files

  doc.rdoc_dir = "rdoc"
end

namespace :vendor do
  desc "Download vendored gems to tmp"
  task :bundle do
    sh({ "BUNDLE_PATH" => "../../tmp/vendor", "BUNDLER_GEM_DEFAULT_DIR" => "../../tmp/vendor" }, "ruby", "--disable-gems", "-r./bundler/spec/support/hax.rb", "-I", "lib", "bundler/spec/support/bundle.rb", "install", "--gemfile=tool/bundler/vendor_gems.rb")
  end

  desc "Install patched vendored gems"
  task install: :bundle do
    sh({ "BUNDLE_GEMFILE" => "tool/bundler/vendor_gems.rb", "BUNDLE_PATH" => "../../tmp/vendor", "BUNDLER_GEM_DEFAULT_DIR" => "../../tmp/vendor" }, "ruby", "-rpathname", "-r./bundler/spec/support/hax.rb", "-I", "lib", "bundler/spec/support/bundle.rb", "exec", "tool/automatiek/vendor.rb")
  end

  desc "Check vendored gems are up to date"
  task check: :install do
    Spec::Rubygems.check_source_control_changes(
      success_message: "Vendored gems are in sync",
      error_message: "Vendored gems are out of sync. Please update the vendored lib patches."
    )
  end
end

namespace :rubocop do
  desc "Setup gems necessary to lint Ruby code"
  task(:setup) do
    sh "ruby", "-I", "lib", "bundler/spec/support/bundle.rb", "install", "--gemfile=tool/bundler/lint_gems.rb"
  end

  desc "Run rubocop. Pass positional arguments as Rake arguments, e.g. `rake 'rubocop:run[-a]'`"
  task :run do |_, args|
    sh "bin/rubocop", *args
  end
end

task rubocop: %w[rubocop:setup rubocop:run]

# --------------------------------------------------------------------
# Creating a release

task prerelease: %w[clobber install_release_dependencies test bundler:build_metadata check_deprecations]
task postrelease: %w[upload guides:publish blog:publish bundler:build_metadata:clean]

desc "Check for deprecated methods with expired deprecation horizon"
task :check_deprecations do
  if v.segments[1] == 0 && v.segments[2] == 0
    sh("bin/rubocop -r ./tool/cops/deprecations --only Rubygems/Deprecations")
  else
    puts "Skipping deprecation checks since not releasing a major version."
  end
end

desc "Install release dependencies"
task :install_release_dependencies do
  require_relative "tool/release"

  Release.install_dependencies!
end

desc "Prepare a release"
task :prepare_release, [:version] => [:install_release_dependencies] do |_t, opts|
  require_relative "tool/release"

  Release.new(opts[:version] || v.to_s).prepare!
end

desc "Install rubygems to local system"
task install: [:clear_package, :package] do
  sh "ruby -Ilib exe/gem install --no-document pkg/rubygems-update-#{v}.gem --backtrace && update_rubygems --no-document --backtrace"
end

desc "Clears previously built package"
task :clear_package do
  rm_rf "pkg"
end

desc "Generates the RubyGems changelog for a specific target version"
task :generate_changelog, [:version] => [:install_release_dependencies] do |_t, opts|
  require_relative "tool/release"

  Release.for_rubygems(opts[:version]).cut_changelog!
end

desc "Release rubygems-#{v}"
task release: :prerelease do
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
      # COPYFILE_DISABLE prevents storing macOS extended attribute data in `._*` files inside the archive
      sh({ "COPYFILE_DISABLE" => "1" }, "tar -czf rubygems-#{v}.tgz --uname=rubygems:0 --gname=rubygems:0 rubygems-#{v}")
    else # If a third variant is added, change this line to: elsif tar_version =~ /GNU tar/
      # GNU Tar, as used by many Linux distros, uses `--owner` and `--group`.
      sh "tar -czf rubygems-#{v}.tgz --owner=rubygems:0 --group=rubygems:0 rubygems-#{v}"
    end
  end
end

desc "Upload the release to GitHub releases"
task :upload_to_github do
  require_relative "tool/release"

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
task upload: %w[upload_to_github upload_to_s3]

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
      sh "git", "diff", "--quiet"
    rescue StandardError
      sh "git", "commit", "command-reference.md", "specification-reference.md",
         "-m", "Rebuild for RubyGems #{v}"
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

      checksums += "* #{basename}  \n"
      checksums += "  #{digest}\n"

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

    require_relative "tool/changelog"
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
      exclude = %r{\A(?:\.|bundler/(?!lib|exe|[^/]+\.md|bundler.gemspec|sbom)|tool/|Rakefile|bin|test|doc)}
      tracked_files = `git ls-files`.split("\n")

      tracked_files.each do |path|
        next unless File.file?(path)
        next if path&.match?(exclude)
        files << path
      end

      # Restore important documents
      %w[
        doc/MAINTAINERS.txt
        doc/bundler/UPGRADING.md
        doc/rubygems/CONTRIBUTING.md
        doc/rubygems/POLICIES.md
        doc/rubygems/UPGRADING.md
      ].each {|f| files << f }

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

license_last_update = nil

desc "Update License list from SPDX.org"
task :update_licenses do
  load "tool/generate_spdx_license_list.rb"
  license_last_update = generate_spdx_license_list
end

desc "Create branch to update License list"
task update_licenses_branch: :update_licenses do
  if license_last_update
    file, mtime = license_last_update
    date = mtime.strftime("%Y-%m-%d")
    branch_name = "license-list-#{date}"

    require "open3"
    stdout, stderr, status = Open3.capture3(*%w[git ls-remote --heads origin], "refs/heads/#{branch_name}")
    raise stderr unless status.success?

    if stdout.empty?
      system(*%w[git checkout -b], branch_name, exception: true)
      system(*%w[git commit -m], "Update SPDX license list as of #{date}", *file, exception: true)
    else
      puts "A license update PR already exists"
    end
  else
    puts "Licenses are in sync"
  end
end

desc "Run specs"
task :spec do
  chdir("bundler") do
    sh("bin/rspec")
  end
end

namespace :dev do
  desc "Ensure dev dependencies are installed"
  task :deps do
    puts Spec::Rubygems.dev_bundle("install")
  end

  desc "Ensure dev dependencies are installed, and make sure no lockfile changes are generated"
  task frozen_deps: :deps do
    Spec::Rubygems.check_source_control_changes(
      success_message: "Development dependencies were installed and the lockfile is in sync",
      error_message: "Development dependencies were installed but the lockfile is out of sync. Commit the updated lockfile and try again"
    )
  end
end

namespace :spec do
  desc "Ensure spec dependencies are installed (deprecated)"
  task deps: "dev:deps" do
    warn "The `spec:deps` task is deprecated because test dependencies are now installed by the tests themselves. Use `dev:deps` task instead."
  end

  desc "Ensure spec dependencies for running in parallel are installed (deprecated)"
  task parallel_deps: "dev:deps" do
    warn "The `spec:parallel_deps` task is deprecated because test dependencies are now installed by the tests themselves and don't need parallelization. Use `dev:deps` task instead."
  end

  desc "Run all specs"
  task all: %w[spec:regular spec:realworld]

  desc "Run the regular spec suite"
  task :regular do
    chdir("bundler") do
      sh("bin/parallel_rspec")
    end
  end

  desc "Run the real-world spec suite"
  task :realworld do
    chdir("bundler") do
      sh("BUNDLER_SPEC_PRE_RECORDED=1 bin/rspec --tag realworld")
    end
  end

  namespace :realworld do
    desc "Re-record cassettes for the realworld specs"
    task :record do
      chdir("bundler") do
        sh("rm -rf spec/support/artifice/vcr_cassettes && bin/rspec --tag realworld")
      end
    end

    task :check_unused_cassettes do
      chdir("bundler") do
        used_cassettes = Dir.glob("spec/support/artifice/used_vcr_cassettes/**/*.txt").flat_map {|f| File.readlines(f).map(&:strip) }
        all_cassettes = Dir.glob("spec/support/artifice/vcr_cassettes/**/*").select {|f| File.file?(f) }
        unused_cassettes = all_cassettes - used_cassettes

        raise "The following cassettes are unused:\n#{unused_cassettes.join("\n")}\n" if unused_cassettes.any?

        puts "No cassettes unused"
      end
    end
  end
end

desc "Check RVM integration"
task :check_rvm_integration do
  # The rubygems-bundler gem is installed by RVM by default and it could easily
  # break when we change bundler. Make sure that binstubs still run with it
  # installed.
  sh("RUBYOPT=-Ilib gem install rubygems-bundler rake && RUBYOPT=-Ibundler/lib rake -T")
end

desc "Check RubyGems integration"
task :check_rubygems_integration do
  # Bundler monkeypatches RubyGems in some ways that could potentially break gem activation.

  # Run a non trivial binstub activation, with two different versions of a dependent gem installed.
  sh("ruby -Ilib -S gem install reline:0.3.0 reline:0.3.1 irb && ruby -Ibundler/lib -rbundler -S irb --version")

  # With two psych versions installed, load a gem that depends on pysch and then load rubygems extensions.
  sh("ruby -Ilib -S gem install psych:5.1.1 psych:5.1.2 rdoc && ruby -Ibundler/lib -rrdoc/task -rbundler/rubygems_ext -e1")
end

namespace :man do
  if RUBY_ENGINE == "jruby"
    task(:build) {}
  else
    file "index.txt" do
      index = Dir["bundler/lib/bundler/man/*.ronn"].map do |ronn|
        roff = "#{File.dirname(ronn)}/#{File.basename(ronn, ".ronn")}"
        [ronn, roff]
      end
      index.map! do |(ronn, roff)|
        date = ENV["MAN_PAGES_DATE"] || Time.now.strftime("%Y-%m-%d")
        sh "bin/ronn --warnings --roff --pipe --date #{date} #{ronn} > #{roff}"
        [File.read(ronn).split(" ").first, File.basename(roff)]
      end
      index = index.sort_by(&:first)
      justification = index.map {|(n, _f)| n.length }.max + 4
      File.open("bundler/lib/bundler/man/index.txt", "w") do |f|
        index.each do |name, filename|
          f << name.ljust(justification) << filename << "\n"
        end
      end
    end
    task build_all_pages: "index.txt"

    desc "Make sure ronn-ng is installed"
    task :check_ronn do
      Spec::Rubygems.gem_require("ronn-ng", "ronn")
    rescue Gem::LoadError => e
      abort("We couldn't activate ronn-ng (#{e.requirement}). Try `gem install ronn-ng:'#{e.requirement}'` to be able to build the help pages")
    end

    desc "Remove all built man pages"
    task :clean do
      leftovers = Dir["bundler/lib/bundler/man/*"].reject do |f|
        File.extname(f) == ".ronn"
      end
      rm leftovers if leftovers.any?
    end

    desc "Build the man pages"
    task build: [:check_ronn, :clean, :build_all_pages]

    desc "Sets target date for building man pages to the one currently present"
    task :set_current_date do
      require "date"
      ENV["MAN_PAGES_DATE"] = Date.parse(File.readlines("bundler/lib/bundler/man/bundle-add.1")[2].split('"')[5]).strftime("%Y-%m-%d")
    end

    desc "Verify man pages are in sync"
    task check: [:check_ronn, :set_current_date, :build] do
      Spec::Rubygems.check_source_control_changes(
        success_message: "Man pages are in sync",
        error_message: "Man pages are out of sync. Please run `rake man:build` and commit the results."
      )
    end
  end
end

task :override_version do
  next unless version = ENV["BUNDLER_SPEC_SUB_VERSION"]
  Spec::Path.replace_version_file(version)
end

namespace :bundler do
  chdir(File.expand_path("bundler", __dir__)) do
    require_relative "bundler/lib/bundler/gem_tasks"
  end
  require_relative "bundler/spec/support/build_metadata"
  require_relative "tool/release"

  Bundler::GemHelper.tag_prefix = "bundler-"

  task :build_metadata do
    Spec::BuildMetadata.write_build_metadata
  end

  namespace :build_metadata do
    task :clean do
      Spec::BuildMetadata.reset_build_metadata
    end
  end

  task build: ["bundler:build_metadata"] do
    Rake::Task["bundler:build_metadata:clean"].tap(&:reenable).invoke
  end

  desc "Push to rubygems.org"
  task "release:rubygem_push" => ["bundler:release:setup", "man:check", "bundler:build_metadata", "bundler:release:github"]

  desc "Generates the Bundler changelog for a specific target version"
  task :generate_changelog, [:version] => [:install_release_dependencies] do |_t, opts|
    Release.for_bundler(opts[:version]).cut_changelog!
  end

  namespace :release do
    desc "Install gems needed for releasing"
    task :setup do
      Release.install_dependencies!
    end

    desc "Push the release to GitHub releases"
    task :github do
      gemspec_version = Bundler::GemHelper.gemspec.version

      Release.for_bundler(gemspec_version).create_for_github!
    end
  end
end

namespace :bundler3 do
  task :install do
    ENV["BUNDLER_SPEC_SUB_VERSION"] = "3.0.0"
    Rake::Task["override_version"].invoke
    Rake::Task["install"].invoke
    sh("git", "checkout", "--", "bundler/lib/bundler/version.rb")
  end
end
