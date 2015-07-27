require 'json'
require 'net/http'

json = Net::HTTP.get('spdx.org', '/licenses/licenses.json')
licenses = JSON.parse(json)['licenses'].map do |licenseObject|
  licenseObject['licenseId']
end

open 'lib/rubygems/util/licenses.rb', 'w' do |io|
  io.write <<-HERE
class Gem::Licenses
  NONSTANDARD = 'Nonstandard'.freeze

  # Software Package Data Exchange (SPDX) standard open-source software
  # license identifiers
  IDENTIFIERS = %w(
    #{licenses.sort.join "\n      "}
  ).freeze
end
  HERE
end
