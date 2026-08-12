# frozen_string_literal: true

require_relative "../vendored_thor"

module Bundler
  class CLI::Credential < Thor
    desc "trust HOST", "Trust the configured credential helper for a registry host"
    def trust(host)
      require_relative "../credential_helper"
      record = Bundler::CredentialHelper.trust(host)
      Bundler.ui.info <<~MESSAGE
        Trusted credential helper:
          Host: #{record["host"]}
          Path: #{record["path"]}
          SHA-256: #{record["sha256"]}
      MESSAGE
    end

    desc "untrust HOST", "Remove trust for a registry host"
    def untrust(host)
      require_relative "../credential_helper"
      if Bundler::CredentialHelper.untrust(host)
        Bundler.ui.info "Removed credential helper trust for #{host.downcase}"
      else
        Bundler.ui.info "No credential helper is trusted for #{host.downcase}"
      end
    end
  end
end
