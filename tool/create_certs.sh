#!/bin/sh

# This script creates RSA and ML-DSA-65 SSL/TLS test certificates.
# It requires OpenSSL >= 3.5 for ML-DSA-65 support.

set -eu

TOP_DIR="$(git rev-parse --show-toplevel)"
TMP_DIR="${TOP_DIR}/tmp/create_certs"

create_certs() {
  genpkey_args="${1}"
  prefix="${2}"

  # CA
  mkdir -p "${TMP_DIR}/${prefix}ca"
  openssl genpkey ${genpkey_args} -out "${TMP_DIR}/${prefix}ca/cakey.pem"
  openssl req -x509 \
    -key "${TMP_DIR}/${prefix}ca/cakey.pem" \
    -subj "/C=JP/ST=Tokyo/O=RubyGemsTest/CN=CA" \
    -not_before 090101000000Z -not_after 491231235959Z \
    -out "${TMP_DIR}/${prefix}ca/cacert.pem"

  # Server
  mkdir -p "${TMP_DIR}/${prefix}server"
  openssl genpkey ${genpkey_args} -out "${TMP_DIR}/${prefix}server/server.key"
  openssl req -new \
    -key "${TMP_DIR}/${prefix}server/server.key" \
    -out "${TMP_DIR}/${prefix}server/csr.pem" \
    -subj "/C=JP/ST=Tokyo/O=RubyGemsTest/CN=localhost"
  openssl x509 -req \
    -in "${TMP_DIR}/${prefix}server/csr.pem" \
    -CA "${TMP_DIR}/${prefix}ca/cacert.pem" \
    -CAkey "${TMP_DIR}/${prefix}ca/cakey.pem" \
    -set_serial 1 \
    -not_before 090101000000Z -not_after 491231235959Z \
    -out "${TMP_DIR}/${prefix}server/cert.pem"

  # Client
  mkdir -p "${TMP_DIR}/${prefix}client"
  openssl genpkey ${genpkey_args} -out "${TMP_DIR}/${prefix}client/client.key"
  openssl req -new \
    -key "${TMP_DIR}/${prefix}client/client.key" \
    -out "${TMP_DIR}/${prefix}client/csr.pem" \
    -subj "/C=JP/ST=Tokyo/O=RubyGemsTest/CN=client"
  openssl x509 -req \
    -in "${TMP_DIR}/${prefix}client/csr.pem" \
    -CA "${TMP_DIR}/${prefix}ca/cacert.pem" \
    -CAkey "${TMP_DIR}/${prefix}ca/cakey.pem" \
    -set_serial 2 \
    -not_before 090101000000Z -not_after 491231235959Z \
    -out "${TMP_DIR}/${prefix}client/cert.pem"

  cp "${TMP_DIR}/${prefix}ca/cacert.pem" \
    "${TOP_DIR}/test/rubygems/${prefix}ca_cert.pem"
  cp "${TMP_DIR}/${prefix}server/cert.pem" \
    "${TOP_DIR}/test/rubygems/${prefix}ssl_cert.pem"
  cp "${TMP_DIR}/${prefix}server/server.key" \
    "${TOP_DIR}/test/rubygems/${prefix}ssl_key.pem"
  cat "${TMP_DIR}/${prefix}client/cert.pem" \
    "${TMP_DIR}/${prefix}client/client.key" > \
    "${TOP_DIR}/test/rubygems/${prefix}client.pem"
}

rm -rf "${TMP_DIR}"

# RSA
create_certs "-algorithm rsa -pkeyopt rsa_keygen_bits:2048" ""

# ML-DSA-65
create_certs "-algorithm mldsa65" "mldsa65_"
