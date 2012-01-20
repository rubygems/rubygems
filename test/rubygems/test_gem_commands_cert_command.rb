require 'rubygems/test_case'
require 'rubygems/commands/cert_command'
require 'rubygems/fix_openssl_warnings' if RUBY_VERSION < "1.9"

unless defined? OpenSSL then
  warn "`gem cert` tests are being skipped, module OpenSSL not found"
end

class TestGemCommandsCertCommand < Gem::TestCase

  def setup
    super

    @cmd = Gem::Commands::CertCommand.new

    root = File.expand_path File.dirname(__FILE__), @@project_dir

    @pkey_file = File.join(root, 'data', 'gem-private_key.pem')
    @cert_file = File.join(root, 'data', 'gem-public_cert.pem')
  end

  def test_execute_add
    use_ui @ui do
      @cmd.send :handle_options, %W[--add #{@cert_file}]
    end

    assert_equal "Added '/CN=rubygems/DC=example/DC=com'\n", @ui.output
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
      @cmd.send :handle_options, %W[--certificate #{@cert_file}]
    end

    assert_equal '', @ui.output
    assert_equal '', @ui.error

    assert_equal File.read(@cert_file),
                 @cmd.options[:issuer_cert].to_s
  end

  def test_execute_list
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT

    use_ui @ui do
      @cmd.send :handle_options, %W[--list]
    end

    assert_equal "/CN=nobody/DC=example\n", @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_private_key
    use_ui @ui do
      @cmd.send :handle_options, %W[--private-key #{@pkey_file}]
    end

    assert_equal '', @ui.output
    assert_equal '', @ui.error

    assert_equal File.read(@pkey_file),
                 @cmd.options[:issuer_key].to_s
  end

  def test_execute_remove
    Gem::Security.trust_dir.trust_cert PUBLIC_CERT

    cert_path = Gem::Security.trust_dir.cert_path(PUBLIC_CERT)

    assert_path_exists cert_path

    use_ui @ui do
      @cmd.send :handle_options, %W[--remove nobody]
    end

    assert_equal "Removed '/CN=nobody/DC=example'\n", @ui.output
    assert_equal '', @ui.error

    refute_path_exists cert_path
  end

  def test_execute_sign
    use_ui @ui do
      @cmd.send :handle_options, %W[
        -K #{@pkey_file} -C #{@cert_file} --sign #{@cert_file}
      ]
    end

    assert_equal '', @ui.output
    assert_equal '', @ui.error

    # HACK this test sucks
  end

end if defined? OpenSSL

