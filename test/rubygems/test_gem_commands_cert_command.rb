require 'rubygems/test_case'
require 'rubygems/commands/cert_command'
require 'rubygems/fix_openssl_warnings' if RUBY_VERSION < "1.9"

unless defined? OpenSSL then
  warn "`gem cert` tests are being skipped, module OpenSSL not found"
end

class TestGemCommandsCertCommand < Gem::TestCase

  ALTERNATE_CERT = load_cert 'alternate'

  PRIVATE_KEY_FILE    = key_path 'private'

  ALTERNATE_CERT_FILE = cert_path 'alternate'
  PUBLIC_CERT_FILE    = cert_path 'public'

  def setup
    super

    @cmd = Gem::Commands::CertCommand.new
  end

  def test_execute_add
    @cmd.handle_options %W[--add #{PUBLIC_CERT_FILE}]

    use_ui @ui do
      @cmd.execute
    end

    cert_path = Gem::Security.trust_dir.cert_path PUBLIC_CERT

    assert_path_exists cert_path

    assert_equal "Added '/CN=nobody/DC=example'\n", @ui.output
    assert_empty @ui.error
  end

  def test_execute_add_twice
    alternate = self.class.cert_path 'alternate'

    @cmd.handle_options %W[
      --add #{PUBLIC_CERT_FILE}
      --add #{ALTERNATE_CERT_FILE}
    ]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EXPECTED
Added '/CN=nobody/DC=example'
Added '/CN=alternate/DC=example'
    EXPECTED

    assert_equal expected, @ui.output
    assert_empty @ui.error
  end

  def test_execute_build
    use_ui @ui do
      Dir.chdir @tempdir do
        @cmd.send :handle_options, %W[--build nobody@example.com]
      end
    end

    output = @ui.output.split "\n"

    assert_equal "Certificate: #{File.join @tempdir, 'gem-public_cert.pem'}",
                 output.shift
    assert_equal "Private Key: #{File.join @tempdir, 'gem-private_key.pem'}",
                 output.shift

    assert_equal "Don't forget to move the key file to somewhere private...",
                 output.shift

    assert_empty output
    assert_empty @ui.error

    assert_path_exists File.join(@tempdir, 'gem-private_key.pem')
    assert_path_exists File.join(@tempdir, 'gem-public_cert.pem')
  end

  def test_execute_certificate
    use_ui @ui do
      @cmd.handle_options %W[--certificate #{PUBLIC_CERT_FILE}]
    end

    assert_equal '', @ui.output
    assert_equal '', @ui.error

    assert_equal PUBLIC_CERT.to_pem, @cmd.options[:issuer_cert].to_pem
  end

  def test_execute_list
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT
    Gem::Security.trust_dir.trust_cert ALTERNATE_CERT

    @cmd.handle_options %W[--list]

    use_ui @ui do
      @cmd.execute
    end

    assert_equal "/CN=nobody/DC=example\n/CN=alternate/DC=example\n",
                 @ui.output
    assert_empty @ui.error
  end

  def test_execute_list_filter
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT
    Gem::Security.trust_dir.trust_cert ALTERNATE_CERT

    @cmd.handle_options %W[--list nobody]

    use_ui @ui do
      @cmd.execute
    end

    assert_equal "/CN=nobody/DC=example\n", @ui.output
    assert_empty @ui.error
  end

  def test_execute_private_key
    use_ui @ui do
      @cmd.send :handle_options, %W[--private-key #{PRIVATE_KEY_FILE}]
    end

    assert_equal '', @ui.output
    assert_equal '', @ui.error

    assert_equal PRIVATE_KEY.to_pem,
                 @cmd.options[:issuer_key].to_pem
  end

  def test_execute_remove
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT

    cert_path = Gem::Security.trust_dir.cert_path PUBLIC_CERT

    assert_path_exists cert_path

    @cmd.handle_options %W[--remove nobody]

    use_ui @ui do
      @cmd.execute
    end

    assert_equal "Removed '/CN=nobody/DC=example'\n", @ui.output
    assert_equal '', @ui.error

    refute_path_exists cert_path
  end

  def test_execute_remove_multiple
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT
    Gem::Security.trust_dir.trust_cert ALTERNATE_CERT

    public_path = Gem::Security.trust_dir.cert_path PUBLIC_CERT
    alternate_path = Gem::Security.trust_dir.cert_path ALTERNATE_CERT

    assert_path_exists public_path
    assert_path_exists alternate_path

    @cmd.handle_options %W[--remove example]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EXPECTED
Removed '/CN=nobody/DC=example'
Removed '/CN=alternate/DC=example'
    EXPECTED

    assert_equal expected, @ui.output
    assert_equal '', @ui.error

    refute_path_exists public_path
    refute_path_exists alternate_path
  end

  def test_execute_remove_twice
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT
    Gem::Security.trust_dir.trust_cert ALTERNATE_CERT

    public_path = Gem::Security.trust_dir.cert_path PUBLIC_CERT
    alternate_path = Gem::Security.trust_dir.cert_path ALTERNATE_CERT

    assert_path_exists public_path
    assert_path_exists alternate_path

    @cmd.handle_options %W[--remove nobody --remove alternate]

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EXPECTED
Removed '/CN=nobody/DC=example'
Removed '/CN=alternate/DC=example'
    EXPECTED

    assert_equal expected, @ui.output
    assert_equal '', @ui.error

    refute_path_exists public_path
    refute_path_exists alternate_path
  end

  def test_execute_sign
    use_ui @ui do
      @cmd.send :handle_options, %W[
        -K #{PRIVATE_KEY_FILE} -C #{PUBLIC_CERT_FILE} --sign #{PUBLIC_CERT_FILE}
      ]
    end

    assert_equal '', @ui.output
    assert_equal '', @ui.error

    # HACK this test sucks
  end

end if defined? OpenSSL

