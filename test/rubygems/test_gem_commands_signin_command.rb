# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/commands/signin_command'
require 'rubygems/installer'

class TestGemCommandsSigninCommand < Gem::TestCase

  def setup
    super
    @cmd = Gem::Commands::SigninCommand.new
  end

  def teardown
    ENV['RUBYGEMS_HOST']               = nil
    Gem.configuration.rubygems_api_key = nil
    super
  end

  def test_execute_when_already_signed_in
    util_capture { @cmd.send(:sign_in) } # to pre-signin

    @after_sign_in_ui = Gem::MockGemUi.new
    util_capture(@after_sign_in_ui) { @cmd.execute }
    assert_match %r{You are already logged in}, @after_sign_in_ui.error
  end

  def test_execute_when_not_already_signed_in
    sign_in_ui = util_capture { @cmd.execute }
    assert_match %r{Signed in.}, sign_in_ui.output
  end

  def test_execute_with_host_supplied
    host = 'http://some-gemcutter-compatible-host.org'
    @cmd.options[:host] = host

    sign_in_ui = util_capture(nil, host) { @cmd.execute }
    assert_match %r{Enter your #{host} credentials.}, sign_in_ui.output
    assert_match %r{Signed in.}, sign_in_ui.output
  end

  # Utility method to capture IO/UI within the block passed

  def util_capture ui_stub = nil, host = nil
    api_key  = 'a5fdbb6ba150cbb83aad2bb2fede64cf040453903'
    response = [api_key, 200, 'OK']
    email    = 'you@example.com'
    password = 'secret'

    ENV['RUBYGEMS_HOST'] = host || Gem.host

    fetcher = Gem::FakeFetcher.new
    # Set the expected response for the Web-API supplied
    fetcher.data["#{ENV['RUBYGEMS_HOST']}/api/v1/api_key"] = response
    Gem::RemoteFetcher.fetcher = fetcher

    sign_in_ui = ui_stub || Gem::MockGemUi.new("#{email}\n#{password}\n")

    use_ui sign_in_ui do
      yield
    end

    sign_in_ui
  end
end
