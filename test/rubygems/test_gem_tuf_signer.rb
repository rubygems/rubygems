require 'rubygems/test_case'
require 'rubygems/tuf'

unless defined?(OpenSSL::SSL) then
  warn 'Skipping Gem::TUF::Signer tests.  openssl not found.'
end

class TestGemTUFSigner < Gem::TestCase
  def setup
    super

    @signable = {
                  "signed" => {
                    "_type"   => "Example",
                    "version" => 1
                  }
                }
  end

  def test_initialize
    Gem::TUF::Signer.new PRIVATE_KEY
  end

  def test_sign
    signer = Gem::TUF::Signer.new PRIVATE_KEY
    signed = signer.sign @signable

    # TODO: get real TUF test vectors
    expected = "5c628a8be727808d1db495a82dd210fc014054696c940ff628dc47e4e2d6" +
               "86947934c35fb694b195dc23cdca25d1fa2a758f9da92d224cbd0d47baa1" +
               "23490d85cacbfe607a5fa0ea5251480d087b7390ecfb43326d03c395ef85" +
               "1f3ba17cbb5ff8e759b90d5edcce55aa1b19611641cc347725327e846481" +
               "04b06a69d6b4859f37843495a5096d86b56389db2a795e5abdcdb70511b3" +
               "c871b7f3f1ff39a204247f358e754e39d318bd767fdd9ede4fcd9a8e1cb6" +
               "aa67f42b6aa6b27087b6635d49ba05dcdc509ae0cc9754d82cdd13a784c9" +
               "e28d347bed47a3810934fa5be7971364ed71a7fca996d2acbf80d6f8798a" +
               "bc2c3f7d80dba1c03cb20d52a008f9f9"

    assert_equal expected, signed['signatures'].first['sig']
  end
end if defined?(OpenSSL::SSL)

