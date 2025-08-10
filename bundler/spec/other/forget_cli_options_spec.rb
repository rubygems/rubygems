# frozen_string_literal: true

RSpec.describe "forget_cli_options feature" do
  describe "default behavior" do
    before do
      # Ensure no explicit configuration is set to test default behavior
      bundle "config unset forget_cli_options"
    end

    it "does not remember CLI options by default" do
      # Install with --path option
      install_gemfile <<-G, artifice: "compact_index"
        source "http://localgemserver.test"
        gem "myrack"
      G

      # Verify the path was not saved to config
      expect(bundle("config get path")).to include("You have not configured a value for `path`")
    end

    it "can be disabled via environment variable" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        install_gemfile <<-G, artifice: "compact_index"
          source "http://localgemserver.test"
          gem "myrack"
        G

        # Verify the path was saved to config
        expect(bundle("config get path")).to include("vendor/bundle")
      end
    end

    it "can be disabled via config" do
      bundle "config set forget_cli_options false"
      
      install_gemfile <<-G, artifice: "compact_index"
        source "http://localgemserver.test"
        gem "myrack"
      G

      # Verify the path was saved to config
      expect(bundle("config get path")).to include("vendor/bundle")
    end

    it "can be explicitly enabled via config" do
      bundle "config set forget_cli_options true"
      
      install_gemfile <<-G, artifice: "compact_index"
        source "http://localgemserver.test"
        gem "myrack"
      G

      # Verify the path was not saved to config
      expect(bundle("config get path")).to include("You have not configured a value for `path`")
    end

    it "respects environment variable over config" do
      bundle "config set forget_cli_options false"
      
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "true") do
        install_gemfile <<-G, artifice: "compact_index"
          source "http://localgemserver.test"
          gem "myrack"
        G

        # Environment variable should override config
        expect(bundle("config get path")).to include("You have not configured a value for `path`")
      end
    end
  end

  describe "logging behavior" do
    it "shows deprecation warnings" do
      bundle "install --path vendor/bundle"
      expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
    end

    it "saves --path flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --path vendor/bundle"
        expect(out).to include("The `--path` flag is being saved to configuration for future bundler invocations")
      end
    end

    it "saves --path flag to config via config setting" do
      bundle "config set forget_cli_options false"
      bundle "install --path vendor/bundle"
      expect(out).to include("The `--path` flag is being saved to configuration for future bundler invocations")
    end

    it "shows --system deprecation warning" do
      bundle "install --system"
      expect(out).to include("[DEPRECATED] The `--system` flag is deprecated")
    end

    it "saves --system flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --system"
        expect(out).to include("The `--system` flag is being saved to configuration for future bundler invocations")
      end
    end

    it "saves --system flag to config via config setting" do
      bundle "config set forget_cli_options false"
      bundle "install --system"
      expect(out).to include("The `--system` flag is being saved to configuration for future bundler invocations")
    end

    it "includes forget_cli_options alternative in --path warning" do
      bundle "install --path vendor/bundle"
      expect(out).to include("Alternatively, you can set `bundle config set forget_cli_options false`")
    end

    it "includes forget_cli_options alternative in --system warning" do
      bundle "install --system"
      expect(out).to include("Alternatively, you can set `bundle config set forget_cli_options false`")
    end

    it "shows --all deprecation warning" do
      bundle "cache --all"
      expect(out).to include("[DEPRECATED] The `--all` flag is deprecated")
    end

    it "saves --all flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "cache --all"
        expect(out).to include("The `--all` flag is being saved to configuration for future bundler invocations")
      end
    end

    it "saves --all flag to config via config setting" do
      bundle "config set forget_cli_options false"
      bundle "cache --all"
      expect(out).to include("The `--all` flag is being saved to configuration for future bundler invocations")
    end

    it "includes forget_cli_options alternative in --all warning" do
      bundle "cache --all"
      expect(out).to include("Alternatively, you can set `bundle config set forget_cli_options false`")
    end
  end

  describe "additional CLI options" do
    it "shows --without deprecation warning" do
      bundle "install --without development"
      expect(out).to include("[DEPRECATED] The `--without` flag is deprecated")
    end

    it "saves --without flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --without development"
        expect(out).to include("The `--without` flag is being saved to configuration for future bundler invocations")
      end
    end

    it "shows --with deprecation warning" do
      bundle "install --with development"
      expect(out).to include("[DEPRECATED] The `--with` flag is deprecated")
    end

    it "saves --with flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --with development"
        expect(out).to include("The `--with` flag is being saved to configuration for future bundler invocations")
      end
    end

    it "shows --deployment deprecation warning" do
      bundle "install --deployment"
      expect(out).to include("[DEPRECATED] The `--deployment` flag is deprecated")
    end

    it "saves --deployment flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --deployment"
        expect(out).to include("The `--deployment` flag is being saved to configuration for future bundler invocations")
      end
    end

    it "shows --frozen deprecation warning" do
      bundle "install --frozen"
      expect(out).to include("[DEPRECATED] The `--frozen` flag is deprecated")
    end

    it "saves --frozen flag to config via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --frozen"
        expect(out).to include("The `--frozen` flag is being saved to configuration for future bundler invocations")
      end
    end
  end

  describe "configuration persistence" do
    it "forgets CLI options when enabled" do
      bundle "install --path vendor/bundle"
      bundle "config get path"
      expect(out).to include("You have not configured a value for `path`")
    end

    it "remembers CLI options when disabled via env var" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --path vendor/bundle"
        bundle "config get path"
        expect(out).to include("vendor/bundle")
      end
    end

    it "remembers multiple CLI options when disabled" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --path vendor/bundle --without development"
        bundle "config get path"
        expect(out).to include("vendor/bundle")
        bundle "config get without"
        expect(out).to include("development")
      end
    end
  end

  describe "real-world workflow scenarios" do
    it "handles workflow with CLI option persistence" do
      # Disable forget_cli_options to test the old behavior
      bundle "config set forget_cli_options false"
      
      # Step 1: Set path configuration (like after git clone)
      bundle "config set --local path vendor/bundle"
      
      # Step 2: Install using configured path
      install_gemfile <<-G, artifice: "compact_index"
        source "http://localgemserver.test"
        gem "myrack"
      G
      
      # Verify gems were installed to configured path
      expect(bundled_app("vendor/bundle/gems/myrack-1.0.0")).to be_directory
      
      # Step 3: Install again without --path (should use configured path)
      bundle "install"
      
      # Verify still using configured path
      expect(bundled_app("vendor/bundle/gems/myrack-1.0.0")).to be_directory
      
      # Step 4: Override with --path for debugging
      bundle "install --path tmp/debug"
      
      # Verify gems installed to debug path
      expect(bundled_app("tmp/debug/gems/myrack-1.0.0")).to be_directory
      
      # Step 5: Install again without --path (should return to configured path)
      bundle "install"
      
      # Verify back to using configured path
      expect(bundled_app("vendor/bundle/gems/myrack-1.0.0")).to be_directory
      
      # Verify the configuration still shows the original path
      bundle "config get path"
      expect(out).to include("vendor/bundle")
    end

    it "handles workflow with CLI option deprecation" do
      # Enable forget_cli_options (default behavior)
      bundle "config set forget_cli_options true"
      
      # Step 1: Set path configuration
      bundle "config set --local path vendor/bundle"
      
      # Step 2: Install using configured path
      install_gemfile <<-G, artifice: "compact_index"
        source "http://localgemserver.test"
        gem "myrack"
      G
      
      # Verify gems were installed to configured path
      expect(bundled_app("vendor/bundle/gems/myrack-1.0.0")).to be_directory
      
      # Step 3: Install with --path override (should show deprecation warning)
      bundle "install --path tmp/debug"
      expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      
      # Verify gems installed to debug path
      expect(bundled_app("tmp/debug/gems/myrack-1.0.0")).to be_directory
      
      # Step 4: Install again without --path (should return to configured path, not persist CLI option)
      bundle "install"
      
      # Verify back to using configured path
      expect(bundled_app("vendor/bundle/gems/myrack-1.0.0")).to be_directory
      
      # Verify the configuration still shows the original path (CLI option not persisted)
      bundle "config get path"
      expect(out).to include("vendor/bundle")
    end

    it "handles workflow with multiple CLI options persistence" do
      # Disable forget_cli_options to test persistence
      bundle "config set forget_cli_options false"
      
      # Step 1: Set initial configuration
      bundle "config set --local path vendor/bundle"
      bundle "config set --local without development"
      
      # Step 2: Install with CLI overrides
      bundle "install --path tmp/debug --without test"
      
      # Verify CLI options were persisted
      bundle "config get path"
      expect(out).to include("tmp/debug")
      bundle "config get without"
      expect(out).to include("test")
      
      # Step 3: Install again (should use persisted CLI options)
      bundle "install"
      
      # Verify using persisted options
      bundle "config get path"
      expect(out).to include("tmp/debug")
      bundle "config get without"
      expect(out).to include("test")
    end

    it "handles workflow with multiple CLI options deprecation" do
      # Enable forget_cli_options
      bundle "config set forget_cli_options true"
      
      # Step 1: Set initial configuration
      bundle "config set --local path vendor/bundle"
      bundle "config set --local without development"
      
      # Step 2: Install with CLI overrides (should show deprecation warnings)
      bundle "install --path tmp/debug --without test"
      expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      expect(out).to include("[DEPRECATED] The `--without` flag is deprecated")
      
      # Step 3: Install again (should return to configured options, not persist CLI options)
      bundle "install"
      
      # Verify back to configured options (CLI options not persisted)
      bundle "config get path"
      expect(out).to include("vendor/bundle")
      bundle "config get without"
      expect(out).to include("development")
    end
  end

  describe "edge cases" do
    it "handles invalid environment variable values gracefully" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "invalid") do
        bundle "install --path vendor/bundle"
        # Should default to enabled (true) behavior
        expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      end
    end

    it "handles empty environment variable values gracefully" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "") do
        bundle "install --path vendor/bundle"
        # Should default to enabled (true) behavior
        expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      end
    end

    it "handles nil environment variable gracefully" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => nil) do
        bundle "install --path vendor/bundle"
        # Should default to enabled (true) behavior
        expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      end
    end

    it "works correctly with multiple CLI options" do
      bundle "install --path vendor/bundle --without development --system"
      expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      expect(out).to include("[DEPRECATED] The `--without` flag is deprecated")
      expect(out).to include("[DEPRECATED] The `--system` flag is deprecated")
    end

    it "works correctly with multiple CLI options when disabled" do
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "false") do
        bundle "install --path vendor/bundle --without development --system"
        expect(out).to include("The `--path` flag is being saved to configuration for future bundler invocations")
        expect(out).to include("The `--without` flag is being saved to configuration for future bundler invocations")
        expect(out).to include("The `--system` flag is being saved to configuration for future bundler invocations")
      end
    end
  end

  describe "feature flag behavior" do
    it "defaults to true when no configuration is set" do
      bundle "config unset forget_cli_options"
      bundle "install --path vendor/bundle"
      expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
    end

    it "respects explicit true configuration" do
      bundle "config set forget_cli_options true"
      bundle "install --path vendor/bundle"
      expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
    end

    it "respects explicit false configuration" do
      bundle "config set forget_cli_options false"
      bundle "install --path vendor/bundle"
      expect(out).to include("The `--path` flag is being saved to configuration for future bundler invocations")
    end

    it "environment variable takes precedence over config" do
      bundle "config set forget_cli_options false"
      with_env_vars("BUNDLE_FORGET_CLI_OPTIONS" => "true") do
        bundle "install --path vendor/bundle"
        expect(out).to include("[DEPRECATED] The `--path` flag is deprecated")
      end
    end
  end
end 