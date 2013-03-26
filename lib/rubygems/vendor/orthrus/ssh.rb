require 'openssl'

module Gem::Orthrus; end

require 'rubygems/vendor/orthrus/ssh/rsa'
require 'rubygems/vendor/orthrus/ssh/dsa'
require 'rubygems/vendor/orthrus/ssh/utils'

module Gem::Orthrus::SSH
  VERSION = '0.6.1'

  def self.load_private(path)
    data = File.read(path)
    if data.index("-----BEGIN RSA PRIVATE KEY-----") == 0
      k = OpenSSL::PKey::RSA.new data
      return RSAPrivateKey.new k
    elsif data.index("-----BEGIN DSA PRIVATE KEY-----") == 0
      k = OpenSSL::PKey::DSA.new data
      return DSAPrivateKey.new k
    else
      raise "Unknown key type in '#{path}'"
    end
  end

  def self.parse_public(data)
    type, key, comment = data.split " ", 3

    case type
    when "ssh-rsa"
      RSAPublicKey.parse key
    when "ssh-dss"
      DSAPublicKey.parse key
    else
      raise "Unknown key type - #{type}"
    end
  end

  def self.load_public(path)
    parse_public File.read(path)
  end

end

# For 1.8/1.9 compat
class String
  unless method_defined? :getbyte
    alias_method :getbyte, :[]
  end
end

