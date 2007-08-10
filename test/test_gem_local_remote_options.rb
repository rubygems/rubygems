require 'test/unit'
require 'test/gemutilities'
require 'rubygems/local_remote_options'

class TestGemLocalRemoteOptions < RubyGemTestCase

  include Gem::LocalRemoteOptions

  attr_accessor :options

  def setup
    super

    @options = {}
    @added_options = []
  end

  def add_option(*args, &block)
    args << block
    @added_options << args
  end

  def test_add_local_remote_options
    add_local_remote_options

    assert_option @added_options.shift, '-l' do |options|
      assert_equal :local, options[:domain]
    end

    assert_option @added_options.shift, '-r' do |options|
      assert_equal :remote, options[:domain]
    end

    assert_option @added_options.shift, '-b' do |options|
      assert_equal :both, options[:domain]
    end

    assert_option @added_options.shift, '-B', 10 do |options|
      assert_equal 10, Gem.configuration.bulk_threshhold
    end

    url = 'http://more-gems.example.com'
    assert_option @added_options.shift, '--source URL', url do |options|
      assert_equal [url], Gem.sources
    end

    proxy_option = @added_options.shift
    url = 'http://proxy.example.com'
    assert_option proxy_option, '-p', url do |options|
      assert_equal({ :http_proxy => url }, options)
      assert_equal url, Gem.configuration[:http_proxy]
    end

    proxy_option.last.call false, @options
    assert_equal({ :http_proxy => :no_proxy }, @options)
    assert_equal :no_proxy, Gem.configuration[:http_proxy]

    assert_equal true, @added_options.empty?, 'new option not tested'
  end

  def test_add_local_remote_options_source_twice
    add_local_remote_options

    s1 = 'http://more-gems.example.com'
    s2 = 'http://even-more-gems.example.com'

    option_callback = @added_options.find { |o| o[1] == '--source URL' }.last

    option_callback.call s1, @options
    option_callback.call s2, @options

    assert_equal [s1, s2], Gem.sources
  end

  def test_local_eh
    assert_equal false, local?

    options[:domain] = :local

    assert_equal true, local?

    options[:domain] = :both

    assert_equal true, local?
  end

  def test_remote_eh
    assert_equal false, remote?

    options[:domain] = :remote

    assert_equal true, remote?

    options[:domain] = :both

    assert_equal true, remote?
  end

  def assert_option(option, flag, value = nil)
    assert_equal flag, option[1]
    option.last.call value, @options

    yield @options

    @options = {}
  end

end

