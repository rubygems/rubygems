# frozen_string_literal: true

RSpec.describe "bundle credential" do
  let(:host) { "gems.example.com" }
  let(:helper) { tmp("credential-helper") }
  let(:marker) { tmp("credential-helper-ran") }

  before do
    gemfile "source \"https://rubygems.org\""
  end

  def write_helper(body, executable: true)
    create_file helper, <<~RUBY
      #!#{Gem.ruby}
      #{body}
    RUBY
    FileUtils.chmod(executable ? 0o755 : 0o644, helper)
  end

  def configure_helper(configured_helper = helper, configured_host = host)
    bundle "config set --local credential.helper.#{configured_host} #{configured_helper}"
  end

  def credentials_for(configured_host = host)
    ruby <<~RUBY
      require "bundler"
      require "bundler/vendored_uri"
      credentials = Bundler.settings.credentials_for(Gem::URI("https://#{configured_host}"))
      print credentials if credentials
    RUBY
  end

  it "gets credentials from a trusted helper" do
    write_helper 'print "user:password"'
    configure_helper

    bundle "credential trust #{host}"
    expect(out).to include("Host: #{host}", "Path: #{helper.realpath}", "SHA-256:")

    credentials_for
    expect(out).to eq("user:password")
  end

  it "does not execute an untrusted helper" do
    write_helper "File.write(#{marker.to_s.dump}, \"ran\")\nprint \"user:password\""
    configure_helper

    credentials_for
    expect(marker).not_to exist
    expect(err).to include(host, helper.to_s, "not trusted")
  end

  it "does not execute a helper after its hash changes" do
    write_helper 'print "user:password"'
    configure_helper
    bundle "credential trust #{host}"

    write_helper "File.write(#{marker.to_s.dump}, \"ran\")\nprint \"attacker:password\""
    credentials_for

    expect(marker).not_to exist
    expect(err).to include(host, helper.to_s, "has changed")
  end

  it "does not share trust between hosts" do
    write_helper "File.write(#{marker.to_s.dump}, \"ran\")\nprint \"user:password\""
    configure_helper
    configure_helper(helper, "other.example.com")
    bundle "credential trust #{host}"

    credentials_for("other.example.com")

    expect(marker).not_to exist
    expect(err).to include("other.example.com", helper.to_s, "not trusted")
  end

  it "rejects invalid hosts" do
    ["gems.example.com/path", "gems.example.com:443", "user@gems.example.com", "[invalid]"].each do |invalid_host|
      bundle "credential trust #{invalid_host}", raise_on_error: false

      expect(last_command).to be_failure
      expect(err).to include("Invalid registry host: #{invalid_host.inspect}")
    end
  end

  it "normalizes an IPv6 host" do
    write_helper 'print "user:password"'
    configure_helper(helper, "[::1]")

    bundle "credential trust ::1"

    expect(out).to include("Host: [::1]")
  end

  it "rejects a relative path" do
    configure_helper("relative-helper")

    bundle "credential trust #{host}", raise_on_error: false

    expect(last_command).to be_failure
    expect(err).to include(host, "must be an absolute path")
  end

  it "does not expand home or environment variables" do
    ["~/credential-helper", "$HOME/credential-helper"].each do |configured_helper|
      configure_helper(configured_helper)
      bundle "credential trust #{host}", raise_on_error: false

      expect(last_command).to be_failure
      expect(err).to include(host, "must be an absolute path")
    end
  end

  it "rejects a configured path with arguments" do
    write_helper 'print "user:password"'
    configure_helper("#{helper} --token")

    bundle "credential trust #{host}", raise_on_error: false

    expect(last_command).to be_failure
    expect(err).to include(host, "does not exist")
  end

  it "does not interpret shell metacharacters" do
    write_helper 'print "user:password"'
    configure_helper("#{helper};touch #{marker}")

    bundle "credential trust #{host}", raise_on_error: false

    expect(last_command).to be_failure
    expect(marker).not_to exist
  end

  it "trusts and executes the real path of a symlink" do
    skip "symlink execution is platform dependent" if Gem.win_platform?

    write_helper 'print "user:password"'
    symlink = tmp("credential-helper-link")
    File.symlink(helper, symlink)
    configure_helper(symlink)

    bundle "credential trust #{host}"
    expect(out).to include("Path: #{helper.realpath}")

    credentials_for
    expect(out).to eq("user:password")
  end

  it "falls back to configured credentials when the helper fails" do
    write_helper "exit 2"
    configure_helper
    bundle "config set --local #{host} fallback:password"
    bundle "credential trust #{host}"

    credentials_for

    expect(out).to eq("fallback:password")
    expect(err).to include(host, helper.to_s, "exit status 2")
  end

  it "trusts and untrusts a helper" do
    write_helper 'print "user:password"'
    configure_helper

    bundle "credential trust #{host}"
    trust_file = home(".bundle/credential_helpers")
    expect(trust_file).to exist
    expect(trust_file.stat.mode & 0o777).to eq(0o600) unless Gem.win_platform?

    bundle "credential untrust #{host}"
    expect(out).to eq("Removed credential helper trust for #{host}")

    credentials_for
    expect(err).to include("not trusted")
  end

  it "does not load trust from local config storage" do
    write_helper "File.write(#{marker.to_s.dump}, \"ran\")\nprint \"user:password\""
    configure_helper
    require "digest/sha2"
    create_file bundled_app(".bundle/credential_helpers"), <<~YAML
      ---
      #{host}:
        host: #{host}
        path: #{helper.realpath}
        sha256: #{Digest::SHA256.file(helper).hexdigest}
    YAML

    credentials_for

    expect(marker).not_to exist
    expect(err).to include("not trusted")
  end

  it "does not expose helper output when the helper fails" do
    credential = "secret-user:secret-password"
    write_helper "print #{credential.dump}\nwarn #{credential.dump}\nexit 1"
    configure_helper
    bundle "config set --local #{host} fallback:password"
    bundle "credential trust #{host}"

    credentials_for

    expect(out).to eq("fallback:password")
    expect(out).not_to include(credential)
    expect(err).not_to include(credential)
  end

  it "falls back for empty output" do
    write_helper "exit 0"
    configure_helper
    bundle "config set --local #{host} fallback:password"
    bundle "credential trust #{host}"

    credentials_for

    expect(out).to eq("fallback:password")
    expect(err).to include(host, helper.to_s, "returned no credentials")
  end

  it "rejects missing and non-executable helpers" do
    configure_helper
    bundle "credential trust #{host}", raise_on_error: false
    expect(err).to include("does not exist")

    write_helper('print "user:password"', executable: false)
    bundle "credential trust #{host}", raise_on_error: false
    expect(err).to include("not executable")
  end

  it "does not execute a helper that loses executable permission after trust" do
    write_helper 'print "user:password"'
    configure_helper
    bundle "credential trust #{host}"
    FileUtils.chmod(0o644, helper)

    credentials_for

    expect(out).to be_empty
    expect(err).to include(host, helper.to_s, "not executable")
  end
end
