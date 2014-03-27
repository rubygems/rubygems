require 'rubygems/test_case'
require 'rubygems/request'
require 'timeout'

class TestGemRequestConnectionPool < Gem::TestCase
  def test_checkout_same_connection
    uri = URI.parse('http://example.org/some_endpoint')

    pools = Gem::Request::ConnectionPools.new nil, []
    conn = pools.checkout_connection_for uri
    pools.checkin_connection_for uri, conn

    assert_equal conn, pools.checkout_connection_for(uri)
  end

  def test_thread_waits_for_connection
    uri = URI.parse('http://example.org/some_endpoint')
    pools = Gem::Request::ConnectionPools.new nil, []
    dummy = Object.new

    conn = pools.checkout_connection_for uri

    t1 = Thread.new {
      timeout(1) do
        pools.checkout_connection_for uri
      end
    }
    assert_raises(Timeout::Error) do
      t1.join
    end
  end
end
