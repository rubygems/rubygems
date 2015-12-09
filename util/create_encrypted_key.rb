# frozen_string_literal: true
require 'openssl'

private_key_path = '../../test/rubygems/private_key.pem'
private_key_path = File.expand_path private_key_path, __FILE__

key = OpenSSL::PKey::RSA.new File.read private_key_path

cipher = OpenSSL::Cipher.new 'DES-CBC'

encrypted_key_path = '../../test/rubygems/encrypted_private_key.pem'
encrypted_key_path = File.expand_path encrypted_key_path, __FILE__

open encrypted_key_path, 'w' do |io|
  io.write key.to_pem cipher, 'Foo bar'
end

