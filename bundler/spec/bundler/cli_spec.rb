# frozen_string_literal: true

require "bundler/cli"

RSpec.describe "bundle executable" do
  it "returns non-zero exit status when passed unrecognized options" do
    bundle "--invalid_argument", raise_on_error: false
    expect(exitstatus).to_not be_zero
  end

  it "returns non-zero exit status when passed unrecognized task" do
    bundle "unrecognized-task", raise_on_error: false
    expect(exitstatus).to_not be_zero
  end

  it "looks for a binary and executes it if it's named bundler-<task>" do
    skip "Could not find command testtasks, probably because not a windows friendly executable" if Gem.win_platform?

    File.open(tmp("bundler-testtasks"), "w", 0o755) do |f|
      ruby = ENV["RUBY"] || "/usr/bin/env ruby"
      f.puts "#!#{ruby}\nputs 'Hello, world'\n"
    end

    with_path_added(tmp) do
      bundle "testtasks"
    end

    expect(out).to eq("Hello, world")
  end

  describe "aliases" do
    it "aliases e to exec" do
      bundle "e --help"

      expect(out_with_macos_man_workaround).to include("bundle-exec")
    end

    it "aliases ex to exec" do
      bundle "ex --help"

      expect(out_with_macos_man_workaround).to include("bundle-exec")
    end

    it "aliases exe to exec" do
      bundle "exe --help"

      expect(out_with_macos_man_workaround).to include("bundle-exec")
    end

    it "aliases c to check" do
      bundle "c --help"

      expect(out_with_macos_man_workaround).to include("bundle-check")
    end

    it "aliases i to install" do
      bundle "i --help"

      expect(out_with_macos_man_workaround).to include("bundle-install")
    end

    it "aliases ls to list" do
      bundle "ls --help"

      expect(out_with_macos_man_workaround).to include("bundle-list")
    end

    it "aliases package to cache" do
      bundle "package --help"

      expect(out_with_macos_man_workaround).to include("bundle-cache")
    end

    it "aliases pack to cache" do
      bundle "pack --help"

      expect(out_with_macos_man_workaround).to include("bundle-cache")
    end

    private

    # Some `man` (e.g., on macOS) always highlights the output even to
    # non-tty.
    def out_with_macos_man_workaround
      out.gsub(/.[\b]/, "")
    end
  end

  context "with no arguments" do
    it "prints a concise help message", bundler: "4" do
      bundle ""
      expect(err).to be_empty
      expect(out).to include("Bundler version #{Bundler::VERSION}").
        and include("\n\nBundler commands:\n\n").
        and include("\n\n  Primary commands:\n").
        and include("\n\n  Utilities:\n").
        and include("\n\nOptions:\n")
    end
  end

  context "when ENV['BUNDLE_GEMFILE'] is set to an empty string" do
    it "ignores it" do
      gemfile bundled_app_gemfile, <<-G
        source "https://gem.repo1"
        gem 'myrack'
      G

      bundle :install, env: { "BUNDLE_GEMFILE" => "" }

      expect(the_bundle).to include_gems "myrack 1.0.0"
    end
  end

  context "with --verbose" do
    before do
      gemfile "source 'https://gem.repo1'"
    end

    it "prints the running command" do
      bundle "info bundler", verbose: true
      expect(out).to start_with("Running `bundle info bundler --verbose` with bundler #{Bundler::VERSION}")

      bundle "install", verbose: true
      expect(out).to start_with("Running `bundle install --verbose` with bundler #{Bundler::VERSION}")
    end

    it "prints the simulated version too when setting is enabled" do
      bundle "config simulate_version 4", verbose: true
      bundle "info bundler", verbose: true
      expect(out).to start_with("Running `bundle info bundler --verbose` with bundler #{Bundler::VERSION} (simulating Bundler 4)")
    end
  end

  context "with verbose configuration" do
    before do
      bundle "config verbose true"
    end

    it "prints the running command" do
      gemfile "source 'https://gem.repo1'"
      bundle "info bundler"
      expect(out).to start_with("Running `bundle info bundler` with bundler #{Bundler::VERSION}")
    end
  end

  describe "bundle outdated" do
    let(:run_command) do
      bundle "install"

      bundle "outdated #{flags}", raise_on_error: false
    end

    before do
      gemfile <<-G
        source "https://gem.repo1"
        gem "myrack", '0.9.1'
      G
    end

    context "with --groups flag" do
      let(:flags) { "--groups" }

      it "prints a message when there are outdated gems" do
        run_command

        expect(out).to include("Gem     Current  Latest  Requested  Groups")
        expect(out).to include("myrack  0.9.1    1.0.0   = 0.9.1    default")
      end
    end

    context "with --parseable" do
      let(:flags) { "--parseable" }

      it "prints a message when there are outdated gems" do
        run_command

        expect(out).to include("myrack (newest 1.0.0, installed 0.9.1, requested = 0.9.1)")
      end
    end

    context "with --groups and --parseable" do
      let(:flags) { "--groups --parseable" }

      it "prints a simplified message when there are outdated gems" do
        run_command

        expect(out).to include("myrack (newest 1.0.0, installed 0.9.1, requested = 0.9.1)")
      end
    end
  end

  describe "printing the outdated warning" do
    shared_examples_for "no warning" do
      it "prints no warning" do
        bundle "fail", env: { "BUNDLER_VERSION" => bundler_version }, raise_on_error: false
        expect(stdboth).to eq("Could not find command \"fail\".")
      end
    end

    let(:bundler_version) { "2.0" }
    let(:latest_version) { nil }
    before do
      bundle "config set --global disable_version_check false"

      pristine_system_gems "bundler-#{bundler_version}"
      if latest_version
        info_path = home(".bundle/cache/compact_index/rubygems.org.443.29b0360b937aa4d161703e6160654e47/info/bundler")
        info_path.parent.mkpath
        info_path.open("w") {|f| f.write "#{latest_version}\n" }
      end
    end

    context "when there is no latest version" do
      include_examples "no warning"
    end

    context "when the latest version is equal to the current version" do
      let(:latest_version) { bundler_version }
      include_examples "no warning"
    end

    context "when the latest version is less than the current version" do
      let(:latest_version) { "0.9" }
      include_examples "no warning"
    end

    context "when the latest version is greater than the current version" do
      let(:latest_version) { "222.0" }
      it "prints the version warning" do
        bundle "fail", env: { "BUNDLER_VERSION" => bundler_version }, raise_on_error: false
        expect(err).to start_with(<<-EOS.strip)
The latest bundler is #{latest_version}, but you are currently running #{bundler_version}.
To update to the most recent version, run `bundle update --bundler`
        EOS
      end

      context "and disable_version_check is set" do
        before { bundle "config set disable_version_check true", env: { "BUNDLER_VERSION" => bundler_version } }
        include_examples "no warning"
      end

      context "running a parseable command" do
        it "prints no warning" do
          bundle "config get --parseable foo", env: { "BUNDLER_VERSION" => bundler_version }
          expect(stdboth).to eq ""

          bundle "platform --ruby", env: { "BUNDLER_VERSION" => bundler_version }, raise_on_error: false
          expect(stdboth).to eq "Could not locate Gemfile"
        end
      end

      context "and is a pre-release" do
        let(:latest_version) { "222.0.0.pre.4" }
        it "prints the version warning" do
          bundle "fail", env: { "BUNDLER_VERSION" => bundler_version }, raise_on_error: false
          expect(err).to start_with(<<-EOS.strip)
The latest bundler is #{latest_version}, but you are currently running #{bundler_version}.
To update to the most recent version, run `bundle update --bundler`
          EOS
        end
      end
    end
  end
end

RSpec.describe "bundler executable" do
  it "shows the bundler version just as the `bundle` executable does" do
    bundler "--version"
    expect(out).to eq("Bundler version #{Bundler::VERSION}")

    bundle "config simulate_version 4"
    bundler "--version"
    expect(out).to eq("#{Bundler::VERSION} (simulating Bundler 4)")
  end
end
