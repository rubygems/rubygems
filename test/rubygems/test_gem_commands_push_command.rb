# frozen_string_literal: true
require 'rubygems/test_case'
require 'rubygems/commands/push_command'

class TestGemCommandsPushCommand < Gem::TestCase
  def setup
    super

    @cmd = Gem::Commands::PushCommand.new
    @cmd.beta_version = false

    # Satisfy signin to only test push logic
    def @cmd.sign_in host; end;

    Gem.configuration.rubygems_api_key =
      'ed244fbf2b1a52e012da8616c512fa47f9aa5250'
  end

  def test_error_for_beta
    @cmd.beta_version = true
    @cmd.latest_rubygems_version = 'foobar'

    assert_raises Gem::MockGemUi::TermError do
      use_ui ui do
        @cmd.execute
      end
    end

    assert_match 'You are using a beta release of RubyGems', ui.error
  end

  def send_gem
    fetcher = Gem::FakeFetcher.new
    Gem::RemoteFetcher.fetcher = fetcher

    response = 'Successfully registered gem: freewill (1.0.0)'
    fetcher.data["#{Gem::DEFAULT_HOST}/api/v1/gems"] = [response, 200, 'OK']

    @cmd.options[:args] = [@path]

    use_ui ui do
      @cmd.execute
    end

    assert_equal Net::HTTP::Post, fetcher.last_request.class
    assert_equal Gem.read_binary(@path), fetcher.last_request.body
    assert_equal 'application/octet-stream',
                 fetcher.last_request['Content-Type']
    assert_match response, ui.output
  end

  def test_default_host
    _spec, @path = util_gem 'freewill', '1.0.0' do |spec|
      spec.metadata['default_gem_server'] = Gem::DEFAULT_HOST
    end
    
    send_gem
  end

  def test_host_as_option
    @cmd.options[:host] = Gem::DEFAULT_HOST
    _spec, @path = util_gem 'freewill', '1.0.0'

    send_gem
  end

  def test_push_host
    _spec, @path = util_gem 'freewill', '1.0.0' do |spec|
      spec.metadata['allowed_push_host'] = Gem::DEFAULT_HOST
    end
    
    send_gem
  end
end
