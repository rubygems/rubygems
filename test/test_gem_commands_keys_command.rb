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

  def test_initialize_proxy
    assert @cmd.handles?(['--http-proxy', 'http://proxy.example.com'])
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

  def test_execute_default
     Gem.configuration.api_keys = { :rubygems =>'701229f217cdf23b1344c7b4b54ca97',
                                   :other => 'a5fdbb6ba150cbb83aad2bb2fede64c' }

     @cmd.handle_options %w(--default other)

     use_ui @ui do
       @cmd.execute
     end

     assert_equal "Now using other API key\n", @ui.output
     assert_equal '', @ui.error
     assert_equal 'a5fdbb6ba150cbb83aad2bb2fede64c',
                  Gem.configuration.rubygems_api_key
  end

  def test_execute_default_with_bad_argument
    Gem.configuration.rubygems_api_key = '701229f217cdf23b1344c7b4b54ca97'

    @cmd.handle_options %w(--default missing)

    use_ui @ui do
      assert_raises MockGemUi::TermError do
        @cmd.execute
      end
    end

   assert_equal '', @ui.output
   assert_match %r{No such API key. You can add it with gem keys --add missing},
                @ui.error
   assert_equal '701229f217cdf23b1344c7b4b54ca97',
                Gem.configuration.rubygems_api_key
  end

  def test_execute_remove
    Gem.configuration.api_keys = { :rubygems =>'701229f217cdf23b1344c7b4b54ca97',
                                   :other => 'a5fdbb6ba150cbb83aad2bb2fede64c' }
    @cmd.handle_options %w(--remove other)

    use_ui @ui do
      @cmd.execute
    end

    refute_includes Gem.configuration.api_keys, :other
    assert_equal "Removed other API key\n", @ui.output
    assert_equal '', @ui.error
  end

  def test_execute_remove_with_bad_argument
    api_keys = {:rubygems =>'701229f217cdf23b1344c7b4b54ca97'}
    Gem.configuration.api_keys = api_keys

    @cmd.handle_options %w(--remove missing)

    use_ui @ui do
      @cmd.execute
    end

    assert_equal "No such API key\n", @ui.output
    assert_equal '', @ui.error
    assert_equal api_keys, Gem.configuration.api_keys
  end

  def test_execute_add
    @fetcher = Gem::FakeFetcher.new
    Gem::RemoteFetcher.fetcher = @fetcher
    @fetcher.data['https://rubygems.org/api/v1/api_key'] = ['701229f217cdf23b1344c7b4b54ca97', 200, 'OK']

    @cmd.handle_options %w(--add another)

    @ui = MockGemUi.new("email@example.com\npassword\n")
    use_ui @ui do
      @cmd.execute
    end

    assert_match %r{Added another API key}, @ui.output
    assert_match '701229f217cdf23b1344c7b4b54ca97', Gem.configuration.api_keys[:another]
  end

  def test_execute_add_with_bad_credentials
    @fetcher = Gem::FakeFetcher.new
    Gem::RemoteFetcher.fetcher = @fetcher
    @fetcher.data['https://rubygems.org/api/v1/api_key'] = ['HTTP Basic: Access denied', 401, 'Not Authorized']

    @cmd.handle_options %w(--add unauthorized)
 
    @ui = MockGemUi.new("email@example.com\npassword\n")
    use_ui @ui do
      assert_raises MockGemUi::TermError do
        @cmd.execute
      end
    end

    refute_includes Gem.configuration.api_keys, :unauthorized
    assert_match %r{Access denied}, @ui.output
  end
end
