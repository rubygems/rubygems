require 'rubygems/test_case'
require 'rubygems/request'
require 'timeout'

class TestGemRequestConnectionPool < Gem::TestCase
  class FakeHttp
    def initialize *args
    end

    def start
    end
  end

  def setup
    super
    @old_client = Gem::Request::ConnectionPools.client
    Gem::Request::ConnectionPools.client = FakeHttp
  end

  def teardown
    Gem::Request::ConnectionPools.client = @old_client
    super
  end

  def test_checkout_same_connection
    uri = URI.parse('http://example/some_endpoint')

    pools = Gem::Request::ConnectionPools.new nil, []
    pool = pools.pool_for uri
    conn = pool.checkout
    pool.checkin conn

    assert_equal conn, pool.checkout
  end

  def test_thread_waits_for_connection
    uri = URI.parse('http://example/some_endpoint')
    pools = Gem::Request::ConnectionPools.new nil, []
    pool  = pools.pool_for uri
    dummy = Object.new

    conn = pool.checkout

    t1 = Thread.new {
      timeout(1) do
        pool.checkout
      end
    }
    assert_raises(Timeout::Error) do
      t1.join
    end
  end
end
