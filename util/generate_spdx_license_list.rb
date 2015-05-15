require 'json'
require 'net/http'

json = Net::HTTP.get('spdx.org', '/licenses/licenses.json')
licenses = JSON.parse(json)['licenses'].map do |licenseObject|
  licenseObject['licenseId']
end

open 'lib/rubygems/util/spdx.rb', 'w' do |io|
  io.write <<-HERE
module Gem
  class SPDX
    NONSTANDARD = 'Nonstandard'.freeze

    IDENTIFIERS = %w(
      #{licenses.sort.join "\n      "}
    ).freeze
  end
end
  HERE
end
