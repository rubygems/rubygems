# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/commands/signin_command'

class TestGemCommandsSigninCommand < Gem::TestCase
  def setup
    super

    Gem.configuration.rubygems_api_key = nil
    Gem.configuration.api_keys.clear

    @api_key     = 'a5fdbb6ba150cbb83aad2bb2fede64cf040453903'
    @email    = 'you@example.com'
    @password = 'secret'

    @cmd = Gem::Commands::SigninCommand.new
    _spec, path = util_gem "freewill", "1.0.0" do |spec|
      spec.metadata['default_gem_server'] = Gem::DEFAULT_HOST
    end
    @cmd.options[:args] = [path]
  end

  def teardown
    Gem.configuration.rubygems_api_key = nil
    Gem.configuration.api_keys.clear

    super
  end

  def test_signin_to_default_host
    host = Gem::DEFAULT_HOST
    pretty_host = 'RubyGems.org'

    sign_in host, pretty_host

    credentials = YAML.load_file Gem.configuration.credentials_path
    assert_equal @api_key, credentials[:rubygems_api_key]
  end

  def test_signin_to_options_host
    host = "https://rubygems.example/"
    
    @cmd.options[:host] = host

    sign_in host

    credentials = YAML.load_file Gem.configuration.credentials_path
    assert_equal @api_key, credentials[host]
  end

  def sign_in host, pretty_host=nil
    skip 'Always uses $stdin on windows' if Gem.win_platform?

    fetcher = Gem::FakeFetcher.new
    fetcher.data["#{host}/api/v1/api_key"] = [@api_key, 200, 'OK']
    Gem::RemoteFetcher.fetcher = fetcher

    
    sign_in_ui = Gem::MockGemUi.new "#{@email}\n#{@password}\n"
    use_ui sign_in_ui do
      @cmd.execute
    end

    assert_match %r{Enter your #{pretty_host || host} credentials.}, sign_in_ui.output
    assert fetcher.last_request["authorization"]
    assert_match %r{Signed in.}, sign_in_ui.output
  end
end


