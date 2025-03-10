# frozen_string_literal: true
require 'openssl'

test_path = File.expand_path('../../test/rubygems', __FILE__)

private_key_path = "#{test_path}/private_key.pem"

key = OpenSSL::PKey::RSA.new File.read private_key_path

cipher = OpenSSL::Cipher.new 'DES-CBC'

encrypted_key_path = "#{test_path}/encrypted_private_key.pem"

open encrypted_key_path, 'w' do |io|
  io.write key.to_pem cipher, 'Foo bar'
end
