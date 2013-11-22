$LOAD_PATH << File.expand_path("../../lib", __FILE__)

require 'openssl'
require 'digest/sha2'
require 'json'
require 'rubygems/util/canonical_json'
require 'rubygems/tuf'
require 'time'



ROLE_NAMES = %w[root targets timestamp release mirrors]

def make_key_pair role_name
  key = OpenSSL::PKey::RSA.new(2048,65537)
  File.write "test/rubygems/tuf/#{role_name}-private.pem", key.to_pem
  File.write "test/rubygems/tuf/#{role_name}-public.pem", key.public_key.to_pem
  key
end

def deserialize_role_key role
  OpenSSL::PKey::RSA.new File.read "test/rubygems/tuf/#{role}-private.pem"
end

def role_metadata key
  { "keyids" => [key.keyid], "threshold" => 1 }
end

def write_signed_metadata role, metadata
  key = deserialize_role_key(role)
  signer = Gem::TUF::Signer.new(key)
  signed_content = signer.sign("signed" => metadata)
  File.write("test/rubygems/tuf/#{role}.txt", JSON.pretty_generate(signed_content))
end

def generate_test_root
  role_keys   = {}
  metadata    = {}
  public_keys = {}

  ROLE_NAMES.each do |role|
    private_role_key = make_key_pair role
    public_role_key  = Gem::TUF::PublicKey.new(private_role_key.public_key)

    role_keys[role] = private_role_key
    metadata[role]  = role_metadata public_role_key
    public_keys[public_role_key.keyid] = public_role_key.as_json
  end

  root = {
    "_type"   => "Root",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "keys"    => public_keys,
    "roles"   => metadata,
      # TODO: Once delegated targets are operational, the root
      # targets.txt should use an offline key.
  }

  write_signed_metadata("root", root)
end

def generate_test_targets
  # TODO: multiple target files
  # TODO: delegation
  test_file_contents = File.read("test/rubygems/tuf/test.txt")

  targets = {
    "_type"   => "Targets",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "targets" => { "test/rubygems/tuf/test.txt" =>
                   { "hashes" => { "sha256" => Digest::SHA256.hexdigest(test_file_contents) },
                     "length" => test_file_contents.length,
                   },
                 },
    }

  write_signed_metadata("targets", targets)
end

def generate_test_timestamp
  release_contents = File.read 'test/rubygems/tuf/release.txt' # TODO
  timestamp = {
    "_type"   => "Timestamp",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "meta" => { "release.txt" =>
                { "hashes" => { "sha256" => Digest::SHA256.hexdigest(release_contents) },
                  "length" => release_contents.length,
                },
              },
    }

  write_signed_metadata("timestamp", timestamp)
end

def generate_test_release
  root_contents = File.read 'test/rubygems/tuf/root.txt'
  targets_contents = File.read 'test/rubygems/tuf/targets.txt'

  release = {
    "_type"   => "Release",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "meta" => { "root.txt" =>
                { "hashes" => { "sha256" => Digest::SHA256.hexdigest(root_contents) },
                  "length" => root_contents.length,
                },

                "targets.txt" =>
                 { "hashes" => { "sha256" => Digest::SHA256.hexdigest(targets_contents) },
                   "length" => targets_contents.length,
                 },
              },
    }

  write_signed_metadata("release", release)
end

def generate_test_metadata
  generate_test_root
  generate_test_targets
  generate_test_release
  generate_test_timestamp
end

generate_test_metadata
