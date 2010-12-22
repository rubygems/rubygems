require File.expand_path('../gemutilities', __FILE__)
require 'rubygems/commands/keys_command.rb'

class TestGemCommandsKeysCommand < RubyGemTestCase
  def setup
    super
    @cmd = Gem::Commands::KeysCommand.new
    @orig_keys = Gem.configuration.api_keys.dup
  end

  def teardown
    Gem.configuration.api_keys = @orig_keys
  end

  def test_execute_list
    Gem.configuration.rubygems_api_key = '701229f217cdf23b1344c7b4b54ca97'
    Gem.configuration.api_keys = { :rubygems =>'701229f217cdf23b1344c7b4b54ca97',
                                   :other => 'a5fdbb6ba150cbb83aad2bb2fede64c' }

    @cmd.handle_options %w(--list)

    use_ui @ui do
      @cmd.execute
    end

    expected = <<-EOF
*** CURRENT KEYS ***

   other
 * rubygems
EOF

    assert_equal expected, @ui.output
    assert_equal '', @ui.error
  end
end
