#!/bin/sh

# This script creates ML-DSA-65 (PQC) test certificates.
# It requires OpenSSL >= 3.5 for ML-DSA-65 support.
# Unlike create_certs.sh, this script doesn't use openssl.cnf.

set -eu

rm -rf mldsa65_ca/ mldsa65_server/ mldsa65_client/

# CA
mkdir mldsa65_ca
openssl genpkey -algorithm mldsa65 -out mldsa65_ca/cakey.pem
openssl req -x509 -key mldsa65_ca/cakey.pem -subj "/C=JP/ST=Tokyo/O=RubyGemsTest/CN=CA" -not_before 090101000000Z -not_after 491231235959Z -out mldsa65_ca/cacert.pem

# Server
mkdir mldsa65_server
openssl genpkey -algorithm mldsa65 -out mldsa65_server/server.key
openssl req -new -key mldsa65_server/server.key -out mldsa65_server/csr.pem -subj "/C=JP/ST=Tokyo/O=RubyGemsTest/CN=localhost"
openssl x509 -req -in mldsa65_server/csr.pem -CA mldsa65_ca/cacert.pem -CAkey mldsa65_ca/cakey.pem -set_serial 1 -not_before 090101000000Z -not_after 491231235959Z -out mldsa65_server/cert.pem

# Client
mkdir mldsa65_client
openssl genpkey -algorithm mldsa65 -out mldsa65_client/client.key
openssl req -new -key mldsa65_client/client.key -out mldsa65_client/csr.pem -subj "/C=JP/ST=Tokyo/O=RubyGemsTest/CN=client"
openssl x509 -req -in mldsa65_client/csr.pem -CA mldsa65_ca/cacert.pem -CAkey mldsa65_ca/cakey.pem -set_serial 2 -not_before 090101000000Z -not_after 491231235959Z -out mldsa65_client/cert.pem

cp mldsa65_ca/cacert.pem $(git rev-parse --show-toplevel)/test/rubygems/mldsa65_ca_cert.pem
cp mldsa65_server/cert.pem $(git rev-parse --show-toplevel)/test/rubygems/mldsa65_ssl_cert.pem
cp mldsa65_server/server.key $(git rev-parse --show-toplevel)/test/rubygems/mldsa65_ssl_key.pem
cat mldsa65_client/cert.pem mldsa65_client/client.key > $(git rev-parse --show-toplevel)/test/rubygems/mldsa65_client.pem
