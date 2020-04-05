# frozen_string_literal: true

require_relative "path"

$LOAD_PATH.unshift(Spec::Path.lib_dir.to_s)
require "bundler"

module Spec
  module Rubygems
    extend self

    def dev_setup
      install_gems(dev_gemfile, dev_lockfile)
    end

    def gem_load(gem_name, bin_container)
      require_relative "rubygems_version_manager"
      RubygemsVersionManager.new(ENV["RGV"]).switch

      gem_load_and_activate(gem_name, bin_container)
    end

    def gem_require(gem_name)
      gem_activate(gem_name)
      require gem_name
    end

    def test_setup
      setup_test_paths

      require "fileutils"

      FileUtils.mkdir_p(Path.home)
      FileUtils.mkdir_p(Path.tmpdir)

      ENV["HOME"] = Path.home.to_s
      ENV["TMPDIR"] = Path.tmpdir.to_s

      require "rubygems/user_interaction"
      Gem::DefaultUserInteraction.ui = Gem::SilentUI.new
    end

    def install_parallel_test_deps
      require "parallel"

      prev_env_test_number = ENV["TEST_ENV_NUMBER"]

      begin
        Parallel.processor_count.times do |n|
          ENV["TEST_ENV_NUMBER"] = (n + 1).to_s

          install_test_deps
        end
      ensure
        ENV["TEST_ENV_NUMBER"] = prev_env_test_number
      end
    end

    def setup_test_paths
      Gem.clear_paths

      ENV["BUNDLE_PATH"] = nil
      ENV["GEM_HOME"] = ENV["GEM_PATH"] = Path.base_system_gems.to_s
      ENV["PATH"] = [Path.bindir, Path.system_gem_path.join("bin"), ENV["PATH"]].join(File::PATH_SEPARATOR)
    end

    def install_test_deps
      setup_test_paths

      install_gems(test_gemfile, test_lockfile)
    end

  private

    def gem_load_and_activate(gem_name, bin_container)
      gem_activate(gem_name)
      load Gem.bin_path(gem_name, bin_container)
    rescue Gem::LoadError => e
      abort "We couln't activate #{gem_name} (#{e.requirement}). Run `gem install #{gem_name}:'#{e.requirement}'`"
    end

    def gem_activate(gem_name)
      gem_requirement = Bundler::LockfileParser.new(File.read(dev_lockfile)).dependencies[gem_name]&.requirement
      gem gem_name, gem_requirement
    end

    def install_gems(gemfile, lockfile)
      old_gemfile = ENV["BUNDLE_GEMFILE"]
      ENV["BUNDLE_GEMFILE"] = gemfile.to_s
      definition = Bundler::Definition.build(gemfile, lockfile, nil)
      definition.validate_runtime!
      Bundler::Installer.install(Path.root, definition, :path => ENV["GEM_HOME"])
    ensure
      ENV["BUNDLE_GEMFILE"] = old_gemfile
    end

    def test_gemfile
      Path.root.join("test_gems.rb")
    end

    def test_lockfile
      lockfile_for(test_gemfile)
    end

    def dev_gemfile
      Path.root.join("dev_gems.rb")
    end

    def dev_lockfile
      lockfile_for(dev_gemfile)
    end

    def lockfile_for(gemfile)
      Pathname.new("#{gemfile.expand_path}.lock")
    end
  end
end
