# frozen_string_literal: true
require "net/http"
require "openssl"
require "fileutils"

URIS = [
  URI("https://rubygems.org"),
  URI("https://www.rubygems.org"),
  URI("https://index.rubygems.org"),
  URI("https://staging.rubygems.org"),
].freeze

HOSTNAMES_TO_MAP = [
  "rubygems.org",
].freeze

def connect_to(uri, store)
  # None of the URIs are IPv6, so URI::Generic#hostname(ruby 1.9.3+) isn't needed
  http = Net::HTTP.new uri.host, uri.port

  http.use_ssl = uri.scheme.downcase == "https"
  http.ssl_version = :TLSv1_2
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  http.cert_store = store

  http.get "/"

  true
rescue OpenSSL::SSL::SSLError
  false
end

def load_certificates(io)
  cert_texts =
    io.read.scan(/^-{5}BEGIN CERTIFICATE-{5}.*?^-{5}END CERTIFICATE-{5}/m)

  cert_texts.map do |cert_text|
    OpenSSL::X509::Certificate.new cert_text
  end
end

def show_certificates(certificates)
  certificates.each do |certificate|
    p certificate.subject.to_a
  end
end

def store_for(certificates)
  store = OpenSSL::X509::Store.new
  certificates.each do |certificate|
    store.add_cert certificate
  end

  store
end

def test_certificates(certificates, uri)
  1.upto certificates.length do |n|
    puts "combinations of #{n} certificates"
    certificates.combination(n).each do |combination|
      match = test_uri uri, combination

      if match
        $needed_combinations << match
        puts
        puts match.map {|certificate| certificate.subject }
        return
      else
        print "."
      end
    end
    puts
  end
end

def test_uri(uri, certificates)
  store = store_for certificates

  verified = connect_to uri, store

  return certificates if verified

  nil
end

def hostname_certificate_mapping(certificates)
  mapping = {}
  HOSTNAMES_TO_MAP.each do |hostname|
    uri = URI("https://#{hostname}")
    certificates.each do |cert|
      match = test_uri uri, [cert]
      mapping[hostname] = cert if match && !mapping.values.include?(cert)
    end
  end
  mapping
end

def write_certificates(certificates)
  mapping = hostname_certificate_mapping(certificates)
  mapping.each do |hostname, certificate|
    subject = certificate.subject.to_a
    name = (subject.assoc("CN") || subject.assoc("OU"))[1]
    name = name.delete " .-"

    FileUtils.mkdir_p("lib/rubygems/ssl_certs/#{hostname}")
    destination = "lib/rubygems/ssl_certs/#{hostname}/#{name}.pem"

    warn "overwriting certificate #{name}" if File.exist? destination

    File.open destination, "w" do |io|
      io.write certificate.to_pem
    end
  end
end

io =
  if ARGV.empty?
    File.open OpenSSL::X509::DEFAULT_CERT_FILE
  else
    ARGF
  end

certificates = load_certificates io
puts "loaded #{certificates.length} certificates"

$needed_combinations = []

URIS.each do |uri|
  puts uri

  test_certificates certificates, uri
end

needed = $needed_combinations.flatten.uniq

write_certificates needed
