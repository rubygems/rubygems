# frozen_string_literal: true

require_relative "vendored_uri"

module Bundler
  class CredentialHelper
    TRUST_FILE = "credential_helpers"

    class << self
      def fetch(host, configured_path)
        new(host, configured_path).fetch
      end

      def trust(host)
        host = normalized_host(host)
        configured_path = Bundler.settings["credential.helper.#{host}"]
        raise InvalidOption, "No credential helper is configured for #{host}" unless configured_path

        helper = new(host, configured_path)
        record = helper.record
        store = load_store
        store[host] = record
        write_store(store)
        record
      end

      def untrust(host)
        host = normalized_host(host)
        store = load_store
        removed = store.delete(host)
        write_store(store) if removed
        removed
      end

      private

      def normalized_host(host)
        host = host.to_s.downcase
        raise Gem::URI::InvalidComponentError if host.empty?

        Gem::URI::Generic.build(host: host).host
      rescue Gem::URI::InvalidComponentError
        raise InvalidOption, "Invalid registry host: #{host.inspect}"
      end

      def trust_file
        Bundler.user_bundle_path.join(TRUST_FILE)
      end

      def load_store
        file = trust_file
        return {} unless file.file?

        require "rubygems/yaml_serializer"
        store = Gem::YAMLSerializer.load(file.read) || {}
        validate_store!(store)
        store
      rescue InvalidOption
        raise
      rescue StandardError
        raise InvalidOption, "Could not read credential helper trust file #{file}"
      end

      def validate_store!(store)
        valid = store.is_a?(Hash) && store.all? do |host, record|
          record.is_a?(Hash) && record["host"] == host &&
            record["path"].is_a?(String) && record["sha256"].match?(/\A[0-9a-f]{64}\z/)
        end
        raise InvalidOption, "Invalid credential helper trust file #{trust_file}" unless valid
      end

      def write_store(store)
        file = trust_file
        SharedHelpers.filesystem_access(file.dirname, :create) do |dir|
          FileUtils.mkdir_p(dir, mode: 0o700)
        end

        require "rubygems/yaml_serializer"
        require "rubygems/util/atomic_file_writer"
        SharedHelpers.filesystem_access(file, :write) do
          Gem::AtomicFileWriter.open(file) do |io|
            io.chmod(0o600) unless Gem.win_platform?
            io.write(Gem::YAMLSerializer.dump(store))
            io.flush
            begin
              io.fsync
            rescue NotImplementedError, SystemCallError
              nil
            end
          end
        end
      end
    end

    def initialize(host, configured_path)
      @host = self.class.send(:normalized_host, host)
      @configured_path = configured_path.to_s
    end

    def fetch
      trusted = self.class.send(:load_store)[@host]
      current = record
      unless trusted
        warn_untrusted(current["path"])
        return
      end

      unless trusted == current
        Bundler.ui.warn "Credential helper for #{@host} at #{current["path"]} has changed; run `bundle credential trust #{@host}` again"
        return
      end

      output = Bundler.with_unbundled_env do
        IO.popen([current["path"]], err: File::NULL, &:read)
      end
      status = Process.last_status
      unless status&.success?
        Bundler.ui.warn "Credential helper for #{@host} at #{current["path"]} failed with exit status #{status&.exitstatus}"
        return
      end

      output = output.to_s.strip
      if output.empty?
        Bundler.ui.warn "Credential helper for #{@host} at #{current["path"]} returned no credentials"
        return
      end
      output
    rescue InvalidOption => e
      Bundler.ui.warn e.message
      nil
    rescue StandardError
      Bundler.ui.warn "Credential helper for #{@host} at #{@configured_path} failed"
      nil
    end

    def record
      path = Pathname.new(@configured_path)
      unless path.absolute?
        raise InvalidOption, "Credential helper for #{@host} must be an absolute path: #{@configured_path}"
      end

      real_path = File.realpath(path)
      unless File.file?(real_path)
        raise InvalidOption, "Credential helper for #{@host} is not a regular file: #{real_path}"
      end
      unless File.executable?(real_path)
        raise InvalidOption, "Credential helper for #{@host} is not executable: #{real_path}"
      end

      require "digest/sha2"
      {
        "host" => @host,
        "path" => real_path,
        "sha256" => ::Digest::SHA256.file(real_path).hexdigest,
      }
    rescue Errno::ENOENT, Errno::ENOTDIR
      raise InvalidOption, "Credential helper for #{@host} does not exist: #{@configured_path}"
    rescue Errno::EACCES
      raise InvalidOption, "Credential helper for #{@host} cannot be accessed: #{@configured_path}"
    end

    private

    def warn_untrusted(path)
      Bundler.ui.warn "Credential helper for #{@host} at #{path} is not trusted; run `bundle credential trust #{@host}`"
    end
  end
end
