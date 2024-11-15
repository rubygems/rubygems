# frozen_string_literal: true

RSpec.describe "bundle exec" do

  it "works with --gemfile flag" do
    system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
    system_gems(system_gems_to_install, path: default_bundle_path)

    gemfile "CustomGemfile", <<-G
      source "https://gem.repo1"
      gem "myrack", "1.0.0"
    G

    bundle "exec --gemfile CustomGemfile myrackup"
    expect(out).to eq("1.0.0")
  end

  it "activates the correct gem" do
    system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
    system_gems(system_gems_to_install, path: default_bundle_path)

    gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
    G

    bundle "exec myrackup"
    expect(out).to eq("0.9.1")
  end

  it "works and prints no warnings when HOME is not writable" do
    system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
    system_gems(system_gems_to_install, path: default_bundle_path)

    gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
    G

    bundle "exec myrackup", env: { "HOME" => "/" }
    expect(out).to eq("0.9.1")
    expect(err).to be_empty
  end

  it "works when the bins are in ~/.bundle" do
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    bundle "exec myrackup"
    expect(out).to eq("1.0.0")
  end

  it "works when running from a random directory" do
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    bundle "exec 'cd #{tmp("gems")} && myrackup'"

    expect(out).to eq("1.0.0")
  end

  it "works when exec'ing something else" do
    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    bundle "exec echo exec"
    expect(out).to eq("exec")
  end

  it "works when exec'ing to ruby" do
    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    bundle "exec ruby -e 'puts %{hi}'"
    expect(out).to eq("hi")
  end

  it "works when exec'ing to rubygems" do
    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    bundle "exec #{gem_cmd} --version"
    expect(out).to eq(Gem::VERSION)
  end

  it "works when exec'ing to rubygems through sh -c" do
    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    bundle "exec sh -c '#{gem_cmd} --version'"
    expect(out).to eq(Gem::VERSION)
  end

  it "works when exec'ing back to bundler to run a remote resolve" do
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
    G

    bundle "exec bundle lock", env: { "BUNDLER_VERSION" => Bundler::VERSION }

    expect(out).to include("Writing lockfile")
  end

  it "respects custom process title when loading through ruby" do
    skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

    script_that_changes_its_own_title_and_checks_if_picked_up_by_ps_unix_utility = <<~'RUBY'
      Process.setproctitle("1-2-3-4-5-6-7")
      puts `ps -ocommand= -p#{$$}`
    RUBY
    gemfile "Gemfile", "source \"https://gem.repo1\""
    create_file "a.rb", script_that_changes_its_own_title_and_checks_if_picked_up_by_ps_unix_utility
    bundle "exec ruby a.rb"
    expect(out).to eq("1-2-3-4-5-6-7")
  end

  it "accepts --verbose" do
    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    bundle "exec --verbose echo foobar"
    expect(out).to eq("foobar")
  end

  it "passes --verbose to command if it is given after the command" do
    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    bundle "exec echo --verbose"
    expect(out).to eq("--verbose")
  end

  it "handles --keep-file-descriptors" do
    skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

    require "tempfile"

    command = Tempfile.new("io-test")
    command.sync = true
    command.write <<-G
      if ARGV[0]
        IO.for_fd(ARGV[0].to_i)
      else
        require 'tempfile'
        io = Tempfile.new("io-test-fd")
        args = %W[#{Gem.ruby} -I#{lib_dir} #{bindir.join("bundle")} exec --keep-file-descriptors #{Gem.ruby} #{command.path} \#{io.to_i}]
        args << { io.to_i => io }
        exec(*args)
      end
    G

    install_gemfile "source \"https://gem.repo1\""
    sys_exec "#{Gem.ruby} #{command.path}"

    expect(out).to be_empty
    expect(err).to be_empty
  end

  it "accepts --keep-file-descriptors" do
    install_gemfile "source \"https://gem.repo1\""
    bundle "exec --keep-file-descriptors echo foobar"

    expect(err).to be_empty
  end

  it "can run a command named --verbose" do
    skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

    install_gemfile "source \"https://gem.repo1\"; gem \"myrack\""
    File.open(bundled_app("--verbose"), "w") do |f|
      f.puts "#!/bin/sh"
      f.puts "echo foobar"
    end
    File.chmod(0o744, bundled_app("--verbose"))
    with_path_as(".") do
      bundle "exec -- --verbose"
    end
    expect(out).to eq("foobar")
  end

  it "handles different versions in different bundles" do
    build_repo2 do
      build_gem "myrack_two", "1.0.0" do |s|
        s.executables = "myrackup"
      end
    end

    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
    G

    install_gemfile bundled_app2("Gemfile"), <<-G, dir: bundled_app2
      source "https://gem.repo2"
      gem "myrack_two", "1.0.0"
    G

    bundle "exec myrackup"

    expect(out).to eq("0.9.1")

    bundle "exec myrackup", dir: bundled_app2
    expect(out).to eq("1.0.0")
  end

  context "with default gems" do
    context "when not specified in Gemfile" do
      it "uses version provided by ruby" do
        skip "irb isn't a default gem" if default_irb_version.empty?

        install_gemfile "source \"https://gem.repo1\""

        default_irb_version = ruby "gem 'irb', '< 999999'; require 'irb'; puts IRB::VERSION", raise_on_error: false
        bundle "exec irb --version"

        expect(out).to include(default_irb_version)
    end

    context "when specified in Gemfile directly" do

      it "uses version specified" do
        default_irb_version = ruby "gem 'irb', '< 999999'; require 'irb'; puts IRB::VERSION", raise_on_error: false
        skip "irb isn't a default gem" if default_irb_version.empty?

        specified_irb_version = "0.9.6"
        build_repo2 do
          build_gem "irb", specified_irb_version do |s|
            s.executables = "irb"
          end
        end

        install_gemfile <<-G
          source "https://gem.repo2"
          gem "irb", "#{specified_irb_version}"
        G

        bundle "exec irb --version"

        expect(out).to eq(specified_irb_version)
        expect(err).to be_empty
      end
    end

    context "when specified in Gemfile indirectly" do
      it "uses resolved version" do
        default_irb_version = ruby "gem 'irb', '< 999999'; require 'irb'; puts IRB::VERSION", raise_on_error: false
        skip "irb isn't a default gem" if default_irb_version.empty?
        indirect_irb_version = "0.9.6"

        build_repo2 do
          build_gem "irb", indirect_irb_version do |s|
            s.executables = "irb"
          end

          build_gem "gem_depending_on_old_irb" do |s|
            s.add_dependency "irb", indirect_irb_version
          end
        end

        install_gemfile <<-G
          source "https://gem.repo2"
          gem "gem_depending_on_old_irb"
        G

        bundle "exec irb --version"

        expect(out).to eq(indirect_irb_version)
        expect(err).to be_empty
      end
    end
  end

  it "warns about executable conflicts" do
    build_repo2 do
      build_gem "myrack_two", "1.0.0" do |s|
        s.executables = "myrackup"
      end
    end

    bundle "config set --global path.system true"

    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
    G

    install_gemfile bundled_app2("Gemfile"), <<-G, dir: bundled_app2
      source "https://gem.repo2"
      gem "myrack_two", "1.0.0"
    G

    bundle "exec myrackup"

    expect(last_command.stderr).to eq(
      "Bundler is using a binstub that was created for a different gem (myrack).\n" \
      "You should run `bundle binstub myrack_two` to work around a system/bundle conflict."
    )
  end

  it "handles gems installed with --without" do
    bundle "config set --local without middleware"
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack" # myrack 0.9.1 and 1.0 exist

      group :middleware do
        gem "myrack_middleware" # myrack_middleware depends on myrack 0.9.1
      end
    G

    bundle "exec myrackup"

    expect(out).to eq("0.9.1")
    expect(the_bundle).not_to include_gems "myrack_middleware 1.0"
  end

  it "does not duplicate already exec'ed RUBYOPT" do
    skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    bundler_setup_opt = "-r#{lib_dir}/bundler/setup"

    rubyopt = opt_add(bundler_setup_opt, ENV["RUBYOPT"])

    bundle "exec 'echo $RUBYOPT'"
    expect(out.split(" ").count(bundler_setup_opt)).to eq(1)

    bundle "exec 'echo $RUBYOPT'", env: { "RUBYOPT" => rubyopt }
    expect(out.split(" ").count(bundler_setup_opt)).to eq(1)
  end

  it "does not duplicate already exec'ed RUBYLIB" do
    skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    rubylib = ENV["RUBYLIB"]
    rubylib = rubylib.to_s.split(File::PATH_SEPARATOR).unshift lib_dir.to_s
    rubylib = rubylib.uniq.join(File::PATH_SEPARATOR)

    bundle "exec 'echo $RUBYLIB'"
    expect(out).to include(rubylib)

    bundle "exec 'echo $RUBYLIB'", env: { "RUBYLIB" => rubylib }
    expect(out).to include(rubylib)
  end

  it "errors nicely when the argument doesn't exist" do
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    bundle "exec foobarbaz", raise_on_error: false
    expect(exitstatus).to eq(127)
    expect(err).to include("bundler: command not found: foobarbaz")
    expect(err).to include("Install missing gem executables with `bundle install`")
  end

  it "errors nicely when the argument is not executable" do
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    bundle "exec touch foo"
    bundle "exec ./foo", raise_on_error: false
    expect(exitstatus).to eq(126)
    expect(err).to include("bundler: not executable: ./foo")
  end

  it "errors nicely when no arguments are passed" do
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "myrack"
    G

    bundle "exec", raise_on_error: false
    expect(exitstatus).to eq(128)
    expect(err).to include("bundler: exec needs a command to run")
  end

  it "raises a helpful error when exec'ing to something outside of the bundle" do
    system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
    system_gems(system_gems_to_install, path: default_bundle_path)

    bundle "config set clean false" # want to keep the myrackup binstub
    install_gemfile <<-G
      source "https://gem.repo1"
      gem "foo"
    G
    [true, false].each do |l|
      bundle "config set disable_exec_load #{l}"
      bundle "exec myrackup", raise_on_error: false
      expect(err).to include "can't find executable myrackup for gem myrack. myrack is not currently included in the bundle, perhaps you meant to add it to your Gemfile?"
    end
  end

  describe "with help flags" do
    each_prefix = proc do |string, &blk|
      1.upto(string.length) {|l| blk.call(string[0, l]) }
    end
    each_prefix.call("exec") do |exec|
      describe "when #{exec} is used" do
        before(:each) do
          skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

          install_gemfile <<-G
            source "https://gem.repo1"
            gem "myrack"
          G

          create_file("print_args", <<-'RUBY')
            #!/usr/bin/env ruby
            puts "args: #{ARGV.inspect}"
          RUBY
          bundled_app("print_args").chmod(0o755)
        end

        it "shows executable's man page when --help is after the executable" do
          bundle "#{exec} print_args --help"
          expect(out).to eq('args: ["--help"]')
        end

        it "shows executable's man page when --help is after the executable and an argument" do
          bundle "#{exec} print_args foo --help"
          expect(out).to eq('args: ["foo", "--help"]')

          bundle "#{exec} print_args foo bar --help"
          expect(out).to eq('args: ["foo", "bar", "--help"]')

          bundle "#{exec} print_args foo --help bar"
          expect(out).to eq('args: ["foo", "--help", "bar"]')
        end

        it "shows executable's man page when the executable has a -" do
          FileUtils.mv(bundled_app("print_args"), bundled_app("docker-template"))
          bundle "#{exec} docker-template build discourse --help"
          expect(out).to eq('args: ["build", "discourse", "--help"]')
        end

        it "shows executable's man page when --help is after another flag" do
          bundle "#{exec} print_args --bar --help"
          expect(out).to eq('args: ["--bar", "--help"]')
        end

        it "uses executable's original behavior for -h" do
          bundle "#{exec} print_args -h"
          expect(out).to eq('args: ["-h"]')
        end

        it "shows bundle-exec's man page when --help is between exec and the executable" do
          with_fake_man do
            bundle "#{exec} --help cat"
          end
          expect(out).to include(%(["#{man_dir}/bundle-exec.1"]))
        end

        it "shows bundle-exec's man page when --help is before exec" do
          with_fake_man do
            bundle "--help #{exec}"
          end
          expect(out).to include(%(["#{man_dir}/bundle-exec.1"]))
        end

        it "shows bundle-exec's man page when -h is before exec" do
          with_fake_man do
            bundle "-h #{exec}"
          end
          expect(out).to include(%(["#{man_dir}/bundle-exec.1"]))
        end

        it "shows bundle-exec's man page when --help is after exec" do
          with_fake_man do
            bundle "#{exec} --help"
          end
          expect(out).to include(%(["#{man_dir}/bundle-exec.1"]))
        end

        it "shows bundle-exec's man page when -h is after exec" do
          with_fake_man do
            bundle "#{exec} -h"
          end
          expect(out).to include(%(["#{man_dir}/bundle-exec.1"]))
        end
      end
    end
  end

  describe "with gem executables" do
    describe "run from a random directory" do
      before(:each) do
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
      end

      it "works when unlocked" do
        bundle "exec 'cd #{tmp("gems")} && myrackup'"
        expect(out).to eq("1.0.0")
      end

      it "works when locked" do
        expect(the_bundle).to be_locked
        bundle "exec 'cd #{tmp("gems")} && myrackup'"
        expect(out).to eq("1.0.0")
      end
    end

    describe "from gems bundled via :path" do
      before(:each) do
        build_lib "fizz", path: home("fizz") do |s|
          s.executables = "fizz"
        end

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "fizz", :path => "#{File.expand_path(home("fizz"))}"
        G
      end

      it "works when unlocked" do
        bundle "exec fizz"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        expect(the_bundle).to be_locked

        bundle "exec fizz"
        expect(out).to eq("1.0")
      end
    end

    describe "from gems bundled via :git" do
      before(:each) do
        build_git "fizz_git" do |s|
          s.executables = "fizz_git"
        end

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "fizz_git", :git => "#{lib_path("fizz_git-1.0")}"
        G
      end

      it "works when unlocked" do
        bundle "exec fizz_git"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        expect(the_bundle).to be_locked
        bundle "exec fizz_git"
        expect(out).to eq("1.0")
      end
    end

    describe "from gems bundled via :git with no gemspec" do
      before(:each) do
        build_git "fizz_no_gemspec", gemspec: false do |s|
          s.executables = "fizz_no_gemspec"
        end

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "fizz_no_gemspec", "1.0", :git => "#{lib_path("fizz_no_gemspec-1.0")}"
        G
      end

      it "works when unlocked" do
        bundle "exec fizz_no_gemspec"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        expect(the_bundle).to be_locked
        bundle "exec fizz_no_gemspec"
        expect(out).to eq("1.0")
      end
    end
  end

  it "performs an automatic bundle install" do
    gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
      gem "foo"
    G

    bundle "config set auto_install 1"
    bundle "exec myrackup"
    expect(out).to include("Installing foo 1.0")
  end

  it "performs an automatic bundle install with git gems" do
    build_git "foo" do |s|
      s.executables = "foo"
    end
    gemfile <<-G
      source "https://gem.repo1"
      gem "myrack", "0.9.1"
      gem "foo", :git => "#{lib_path("foo-1.0")}"
    G

    bundle "config set auto_install 1"
    bundle "exec foo"
    expect(out).to include("Fetching myrack 0.9.1")
    expect(out).to include("Fetching #{lib_path("foo-1.0")}")
    expect(out.lines).to end_with("1.0")
  end

  it "loads the correct optparse when `auto_install` is set, and optparse is a dependency" do
    build_repo4 do
      build_gem "fastlane", "2.192.0" do |s|
        s.executables = "fastlane"
        s.add_dependency "optparse", "~> 999.999.999"
      end

      build_gem "optparse", "999.999.998"
      build_gem "optparse", "999.999.999"
    end

    system_gems "optparse-999.999.998", gem_repo: gem_repo4

    bundle "config set auto_install 1"
    bundle "config set --local path vendor/bundle"

    gemfile <<~G
      source "https://gem.repo4"
      gem "fastlane"
    G

    bundle "exec fastlane"
    expect(out).to include("Installing optparse 999.999.999")
    expect(out).to include("2.192.0")
  end

  describe "with gems bundled via :path with invalid gemspecs" do
    it "outputs the gemspec validation errors" do
      build_lib "foo"

      gemspec = lib_path("foo-1.0").join("foo.gemspec").to_s
      File.open(gemspec, "w") do |f|
        f.write <<-G
          Gem::Specification.new do |s|
            s.name    = 'foo'
            s.version = '1.0'
            s.summary = 'TODO: Add summary'
            s.authors = 'Me'
            s.rubygems_version = nil
          end
        G
      end

      gemfile <<-G
        source "https://gem.repo1"
        gem "foo", :path => "#{lib_path("foo-1.0")}"
      G

      bundle "exec irb", raise_on_error: false

      expect(err).to match("The gemspec at #{lib_path("foo-1.0").join("foo.gemspec")} is not valid")
      expect(err).to match(/missing value for attribute rubygems_version|rubygems_version must not be nil/)
    end
  end

  describe "with gems bundled for deployment" do
    it "works when calling bundler from another script" do
      skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

      gemfile <<-G
      source "https://gem.repo1"

      module Monkey
        def bin_path(a,b,c)
          raise Gem::GemNotFoundException.new('Fail')
        end
      end
      Bundler.rubygems.extend(Monkey)
      G
      bundle "config set path.system true"
      bundle "install"
      bundle "exec ruby -e '`bundle -v`; puts $?.success?'", env: { "BUNDLER_VERSION" => Bundler::VERSION }
      expect(out).to match("true")
    end
  end

  describe "bundle exec gem uninstall" do
    it "works" do
      build_repo4 do
        build_gem "foo"
      end

      install_gemfile <<-G
        source "https://gem.repo4"

        gem "foo"
      G
      bundle "exec #{gem_cmd} uninstall foo"
      expect(out).to eq("Successfully uninstalled foo-1.0")
    end
  end

  context "`load`ing a ruby file instead of `exec`ing" do
    it "runs" do
      skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }
      exit_code = 0

      expected_err = ""
      bundle "exec #{path} arg1 arg2", raise_on_error: false

      expect(exitstatus).to eq(exit_code)
      expect(err).to eq(expected_err)
      expect(out).to eq(expected)
    end

    context "the executable exits explicitly" do

      context "with exit 0" do
        it "runs" do
          skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

          system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
          system_gems(system_gems_to_install, path: default_bundle_path)

          install_gemfile <<-G
            source "https://gem.repo1"
            gem "myrack"
          G
          path = bundled_app("ruby_executable")
          shebang = "#!/usr/bin/env ruby"
          exit_code = 0
          executable = <<~RUBY.strip
            #{shebang}

            require "myrack"
            puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
            puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
            puts "MYRACK: \#{MYRACK}"
            process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
            puts "PROCESS: \#{process_title}"
            exit #{exit_code}
            puts 'POST_EXIT'
          RUBY
          exec = "EXEC: load"
          args = "ARGS: #{path} arg1 arg2"
          myrack = "MYRACK: 1.0.0"
          process = do
            title = "PROCESS: #{path}"
            title += " arg1 arg2"
            title
          end
          expected = [exec, args, myrack, process].join("\n")
          bundled_app(path).open("w") {|f| f << executable }

          expected_err = ""
          bundle "exec #{path} arg1 arg2", raise_on_error: false

          expect(exitstatus).to eq(exit_code)
          expect(err).to eq(expected_err)
          expect(out).to eq(expected)
        end
      end

      context "with exit 99" do

        it "runs" do
          skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

          system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
          system_gems(system_gems_to_install, path: default_bundle_path)

          install_gemfile <<-G
            source "https://gem.repo1"
            gem "myrack"
          G
          path = bundled_app("ruby_executable")
          shebang = "#!/usr/bin/env ruby"
          exit_code = 99
          executable = <<~RUBY.strip
            #{shebang}

            require "myrack"
            puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
            puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
            puts "MYRACK: \#{MYRACK}"
            process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
            puts "PROCESS: \#{process_title}"
            exit #{exit_code}
            puts 'POST_EXIT'
          RUBY
          exec = "EXEC: load"
          args = "ARGS: #{path} arg1 arg2"
          myrack = "MYRACK: 1.0.0"
          process = do
            title = "PROCESS: #{path}"
            title += " arg1 arg2"
            title
          end
          expected = [exec, args, myrack, process].join("\n")
          bundled_app(path).open("w") {|f| f << executable }

          expected_err = ""
          bundle "exec #{path} arg1 arg2", raise_on_error: false

          expect(exitstatus).to eq(exit_code)
          expect(err).to eq(expected_err)
          expect(out).to eq(expected)
        end
      end
    end

    context "the executable exits by SignalException" do
      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = exit_status_for_signal(Signal.list["TERM"])
        executable = <<~RUBY.strip
          #{shebang}

          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
          exit #{exit_code}
          puts 'POST_EXIT'
          raise SignalException, 'SIGTERM'
        RUBY
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        bundled_app(path).open("w") {|f| f << executable }

        expected_err = ""
        bundle "exec #{path} arg1 arg2", raise_on_error: false

        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "the executable is empty" do
      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = exit_status_for_signal(Signal.list["TERM"])
        exit_code = 0
        executable = <<~RUBY.strip
          #{shebang}

          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
          exit #{exit_code}
          puts 'POST_EXIT'
          raise SignalException, 'SIGTERM'
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        expected = ""
        bundled_app(path).open("w") {|f| f << executable }

        expected_err = "#{path} is empty"
        bundle "exec #{path} arg1 arg2", raise_on_error: false


        subject
        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "the executable raises" do
      it "runs like a normally executed executable" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = exit_status_for_signal(Signal.list["TERM"])
        exit_code = 1
        executable = <<~RUBY.strip
          #{shebang}

          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
          raise 'ERROR'
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        expected = ""
        bundled_app(path).open("w") {|f| f << executable }

        expected_err = do
        /\Abundler: failed to load command: #{Regexp.quote(path.to_s)} \(#{Regexp.quote(path.to_s)}\)\n#{Regexp.quote(path.to_s)}:10:in [`']<top \(required\)>': ERROR \(RuntimeError\)/
        end

        bundle "exec #{path} arg1 arg2", raise_on_error: false

        expect(exitstatus).to eq(exit_code)
        expect(err).to match(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "the executable raises an error without a backtrace" do

      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = exit_status_for_signal(Signal.list["TERM"])
        exit_code = 1
        executable = <<~RUBY.strip
          #{shebang}

          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
          class Err < Exception
          def backtrace; end;
          end
          raise Err
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        expected = ""
        bundled_app(path).open("w") {|f| f << executable }

        expected_err = "bundler: failed to load command: #{path} (#{path})\n#{system_gem_path("bin/bundle")}: Err (Err)"

        bundle "exec #{path} arg1 arg2", raise_on_error: false

        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "when the file uses the current ruby shebang" do

      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        shebang = "#!#{Gem.ruby}"
        exit_code = exit_status_for_signal(Signal.list["TERM"])
        exit_code = 1
        executable = <<~RUBY.strip
          #{shebang}

          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        bundled_app(path).open("w") {|f| f << executable }

        expected_err = "bundler: failed to load command: #{path} (#{path})\n#{system_gem_path("bin/bundle")}: Err (Err)"

        bundle "exec #{path} arg1 arg2", raise_on_error: false

        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "when Bundler.setup fails", bundler: "< 3" do
      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)

        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = 0
        exit_code = Bundler::GemNotFound.new.status_code
        executable = <<~RUBY.strip
          #{shebang}

          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        expected = ""
        bundled_app(path).open("w") {|f| f << executable }

        expected_err = ""
        expected_err =  <<-EOS.strip
        Could not find gem 'myrack (= 2)' in locally installed gems.
        
        The source contains the following gems matching 'myrack':
          * myrack-0.9.1
          * myrack-1.0.0
        Run `bundle install` to install missing gems.
              EOS

        bundle "exec #{path} arg1 arg2", raise_on_error: false
        
        gemfile <<-G
        source "https://gem.repo1"
        gem 'myrack', '2'
        G
        ENV["BUNDLER_FORCE_TTY"] = "true"

        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "when Bundler.setup fails", bundler: "3" do
      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      exit_code = 0
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      executable = ""
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }

      expected_err = ""

      bundle "exec #{path} arg1 arg2", raise_on_error: false
      
      gemfile <<-G
      source "https://gem.repo1"
      gem 'myrack', '2'
      G
      ENV["BUNDLER_FORCE_TTY"] = "true"

      let(:exit_code) { Bundler::GemNotFound.new.status_code }
      let(:expected) { "" }
      let(:expected_err) { <<-EOS.strip }
Could not find gem 'myrack (= 2)' in locally installed gems.

The source contains the following gems matching 'myrack':
  * myrack-1.0.0
Run `bundle install` to install missing gems.
      EOS

      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        subject
        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "when Bundler.setup fails and Gemfile is not the default" do
      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      exit_code = 0
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      executable = ""
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }

      expected_err = ""

      bundle "exec #{path} arg1 arg2", raise_on_error: false
      before do
        gemfile "CustomGemfile", <<-G
          source "https://gem.repo1"
          gem 'myrack', '2'
        G
        ENV["BUNDLER_FORCE_TTY"] = "true"
        ENV["BUNDLE_GEMFILE"] = "CustomGemfile"
        ENV["BUNDLER_ORIG_BUNDLE_GEMFILE"] = nil
      end

      let(:exit_code) { Bundler::GemNotFound.new.status_code }
      let(:expected) { "" }

      it "prints proper suggestion" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        subject
        expect(exitstatus).to eq(exit_code)
        expect(err).to include("Run `bundle install --gemfile CustomGemfile` to install missing gems.")
        expect(out).to eq(expected)
      end
    end

    context "when the executable exits non-zero via at_exit" do
      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      exit_code = 0
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      executable = ""
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }

      expected_err = ""

      bundle "exec #{path} arg1 arg2", raise_on_error: false
      let(:executable) { super() + "\n\nat_exit { $! ? raise($!) : exit(1) }" }
      let(:exit_code) { 1 }

      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        subject
        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "when disable_exec_load is set" do
      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      exit_code = 0
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      executable = ""
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }

      expected_err = ""

      bundle "exec #{path} arg1 arg2", raise_on_error: false
      let(:exec) { "EXEC: exec" }
      let(:process) { "PROCESS: ruby #{path} arg1 arg2" }

      before do
        bundle "config set disable_exec_load true"
      end

      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        subject
        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end
    end

    context "regarding $0 and __FILE__" do
      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      exit_code = 0
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      executable = ""
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }

      expected_err = ""

      bundle "exec #{path} arg1 arg2", raise_on_error: false
      let(:executable) { super() + <<-'RUBY' }

        puts "$0: #{$0.inspect}"
        puts "__FILE__: #{__FILE__.inspect}"
      RUBY

      let(:expected) { super() + <<-EOS.chomp }

$0: #{path.to_s.inspect}
__FILE__: #{path.to_s.inspect}
      EOS

      it "runs" do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        subject
        expect(exitstatus).to eq(exit_code)
        expect(err).to eq(expected_err)
        expect(out).to eq(expected)
      end

      context "when the path is relative" do
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)
  
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = 0
        executable = <<~RUBY.strip
          #{shebang}
  
          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        bundled_app(path).open("w") {|f| f << executable }
  
        expected_err = ""
  
        bundle "exec #{path} arg1 arg2", raise_on_error: false
        let(:path) { super().relative_path_from(bundled_app) }

        it "runs" do
          skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

          subject
          expect(exitstatus).to eq(exit_code)
          expect(err).to eq(expected_err)
          expect(out).to eq(expected)
        end
      end

      context "when the path is relative with a leading ./" do
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)
  
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = 0
        executable = <<~RUBY.strip
          #{shebang}
  
          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        bundled_app(path).open("w") {|f| f << executable }
  
        expected_err = ""
  
        bundle "exec #{path} arg1 arg2", raise_on_error: false
        let(:path) { Pathname.new("./#{super().relative_path_from(bundled_app)}") }

        pending "relative paths with ./ have absolute __FILE__"
      end
    end

    context "signal handling" do
      system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
      system_gems(system_gems_to_install, path: default_bundle_path)

      install_gemfile <<-G
        source "https://gem.repo1"
        gem "myrack"
      G
      path = bundled_app("ruby_executable")
      shebang = "#!/usr/bin/env ruby"
      exit_code = 0
      executable = <<~RUBY.strip
        #{shebang}

        require "myrack"
        puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
        puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
        puts "MYRACK: \#{MYRACK}"
        process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
        puts "PROCESS: \#{process_title}"
      RUBY
      executable = ""
      exec = "EXEC: load"
      args = "ARGS: #{path} arg1 arg2"
      myrack = "MYRACK: 1.0.0"
      process = do
        title = "PROCESS: #{path}"
        title += " arg1 arg2"
        title
      end
      expected = [exec, args, myrack, process].join("\n")
      bundled_app(path).open("w") {|f| f << executable }

      expected_err = ""

      bundle "exec #{path} arg1 arg2", raise_on_error: false
      let(:test_signals) do
        open3_reserved_signals = %w[CHLD CLD PIPE]
        reserved_signals = %w[SEGV BUS ILL FPE VTALRM KILL STOP EXIT]
        bundler_signals = %w[INT]

        Signal.list.keys - (bundler_signals + reserved_signals + open3_reserved_signals)
      end

      context "signals being trapped by bundler" do
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)
  
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = 0
        executable = <<~RUBY.strip
          #{shebang}
  
          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        bundled_app(path).open("w") {|f| f << executable }
  
        expected_err = ""
  
        bundle "exec #{path} arg1 arg2", raise_on_error: false
        let(:executable) { <<~RUBY }
          #{shebang}
          begin
            Thread.new do
              puts 'Started' # For process sync
              STDOUT.flush
              sleep 1 # ignore quality_spec
              raise "Didn't receive INT at all"
            end.join
          rescue Interrupt
            puts "foo"
          end
        RUBY

        it "receives the signal" do
          skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

          bundle("exec #{path}") do |_, o, thr|
            o.gets # Consumes 'Started' and ensures that thread has started
            Process.kill("INT", thr.pid)
          end

          expect(out).to eq("foo")
        end
      end

      context "signals not being trapped by bunder" do
        system_gems_to_install = %w[myrack-1.0.0 myrack-0.9.1]
        system_gems(system_gems_to_install, path: default_bundle_path)
  
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        path = bundled_app("ruby_executable")
        shebang = "#!/usr/bin/env ruby"
        exit_code = 0
        executable = <<~RUBY.strip
          #{shebang}
  
          require "myrack"
          puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
          puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
          puts "MYRACK: \#{MYRACK}"
          process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
          puts "PROCESS: \#{process_title}"
        RUBY
        executable = ""
        exec = "EXEC: load"
        args = "ARGS: #{path} arg1 arg2"
        myrack = "MYRACK: 1.0.0"
        process = do
          title = "PROCESS: #{path}"
          title += " arg1 arg2"
          title
        end
        expected = [exec, args, myrack, process].join("\n")
        bundled_app(path).open("w") {|f| f << executable }
  
        expected_err = ""
  
        bundle "exec #{path} arg1 arg2", raise_on_error: false
        let(:executable) { <<~RUBY }
          #{shebang}

          signals = #{test_signals.inspect}
          result = signals.map do |sig|
            Signal.trap(sig, "IGNORE")
          end
          puts result.select { |ret| ret == "IGNORE" }.count
        RUBY

        it "makes sure no unexpected signals are restored to DEFAULT" do
          skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

          test_signals.each do |n|
            Signal.trap(n, "IGNORE")
          end

          bundle("exec #{path}")

          expect(out).to eq(test_signals.count.to_s)
        end
      end
    end
  end

  context "nested bundle exec" do
    context "when bundle in a local path" do
      before do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        gemfile <<-G
          source "https://gem.repo1"
          gem "myrack"
        G
        bundle "config set path vendor/bundler"
        bundle :install
      end

      it "correctly shells out" do
        file = bundled_app("file_that_bundle_execs.rb")
        create_file(file, <<-RUBY)
          #!#{Gem.ruby}
          puts `bundle exec echo foo`
        RUBY
        file.chmod(0o777)
        bundle "exec #{file}", env: { "PATH" => path }
        expect(out).to eq("foo")
      end
    end

    context "when Kernel.require uses extra monkeypatches" do
      before do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        install_gemfile "source \"https://gem.repo1\""
      end

      it "does not undo the monkeypatches" do
        karafka = bundled_app("bin/karafka")
        create_file(karafka, <<~RUBY)
          #!#{Gem.ruby}

          module Kernel
            module_function

            alias_method :require_before_extra_monkeypatches, :require

            def require(path)
              puts "requiring \#{path} used the monkeypatch"

              require_before_extra_monkeypatches(path)
            end
          end

          Bundler.setup(:default)

          require "foo"
        RUBY
        karafka.chmod(0o777)

        foreman = bundled_app("bin/foreman")
        create_file(foreman, <<~RUBY)
          #!#{Gem.ruby}

          puts `bundle exec bin/karafka`
        RUBY
        foreman.chmod(0o777)

        bundle "exec #{foreman}"
        expect(out).to eq("requiring foo used the monkeypatch")
      end
    end

    context "when gemfile and path are configured", :ruby_repo do
      before do
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?

        build_repo2 do
          build_gem "rails", "6.1.0" do |s|
            s.executables = "rails"
          end
        end

        bundle "config set path vendor/bundle"
        bundle "config set gemfile gemfiles/myrack_6_1.gemfile"

        gemfile(bundled_app("gemfiles/myrack_6_1.gemfile"), <<~RUBY)
          source "https://gem.repo2"

          gem "rails", "6.1.0"
        RUBY

        # A Gemfile needs to be in the root to trick bundler's root resolution
        gemfile "source 'https://gem.repo1'"

        bundle "install", artifice: "compact_index", env: { "BUNDLER_SPEC_GEM_REPO" => gem_repo2.to_s }
      end

      it "can still find gems after a nested subprocess" do
        script = bundled_app("bin/myscript")

        create_file(script, <<~RUBY)
          #!#{Gem.ruby}

          puts `bundle exec rails`
        RUBY

        script.chmod(0o777)

        bundle "exec #{script}"

        expect(err).to be_empty
        expect(out).to eq("6.1.0")
      end

      it "can still find gems after a nested subprocess when using bundler (with a final r) executable" do
        script = bundled_app("bin/myscript")

        create_file(script, <<~RUBY)
          #!#{Gem.ruby}

          puts `bundler exec rails`
        RUBY

        script.chmod(0o777)

        bundle "exec #{script}"

        expect(err).to be_empty
        expect(out).to eq("6.1.0")
      end
    end

    context "with a system gem that shadows a default gem" do
      it "only leaves the default gem in the stdlib available" do
        expected = ruby "gem 'openssl', '< 999999'; require 'openssl'; puts OpenSSL::VERSION", artifice: nil, raise_on_error: false
        openssl_version = "99.9.9"
        skip "https://github.com/rubygems/rubygems/issues/3351" if Gem.win_platform?
        skip "openssl isn't a default gem" if expected.empty?

        install_gemfile "source \"https://gem.repo1\"" # must happen before installing the broken system gem

        build_repo4 do
          build_gem "openssl", openssl_version do |s|
            s.write("lib/openssl.rb", <<-RUBY)
              raise "custom openssl should not be loaded, it's not in the gemfile!"
            RUBY
          end
        end

        system_gems("openssl-#{openssl_version}", gem_repo: gem_repo4)

        file = bundled_app("require_openssl.rb")
        create_file(file, <<-RUBY)
          #!/usr/bin/env ruby
          require "openssl"
          puts OpenSSL::VERSION
          warn Gem.loaded_specs.values.map(&:full_name)
        RUBY
        file.chmod(0o777)

        env = { "PATH" => path }
        aggregate_failures do
          expect(bundle("exec #{file}", artifice: nil, env: env)).to eq(expected)
          expect(bundle("exec bundle exec #{file}", artifice: nil, env: env)).to eq(expected)
          expect(bundle("exec ruby #{file}", artifice: nil, env: env)).to eq(expected)
          expect(run(file.read, artifice: nil, env: env)).to eq(expected)
        end

        skip "ruby_core has openssl and rubygems in the same folder, and this test needs rubygems require but default openssl not in a directly added entry in $LOAD_PATH" if ruby_core?
        # sanity check that we get the newer, custom version without bundler
        sys_exec "#{Gem.ruby} #{file}", env: env, raise_on_error: false
        expect(err).to include("custom openssl should not be loaded")
      end
    end

    context "with a git gem that includes extensions", :ruby_repo do
      before do
        build_git "simple_git_binary", &:add_c_extension
        bundle "config set --local path .bundle"
        install_gemfile <<-G
          source "https://gem.repo1"
          gem "simple_git_binary", :git => '#{lib_path("simple_git_binary-1.0")}'
        G
      end

      it "allows calling bundle install" do
        bundle "exec bundle install"
      end

      it "allows calling bundle install after removing gem.build_complete" do
        FileUtils.rm_rf Dir[bundled_app(".bundle/**/gem.build_complete")]
        bundle "exec #{Gem.ruby} -S bundle install"
      end
    end
  end
end
