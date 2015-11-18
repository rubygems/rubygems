require 'json'
require 'net/http'

json = Net::HTTP.get('spdx.org', '/licenses/licenses.json')
licenses = JSON.parse(json)['licenses'].map do |licenseObject|
  licenseObject['licenseId']
end

open 'lib/rubygems/util/licenses.rb', 'w' do |io|
  io.write <<-RUBY
class Gem::Licenses
  NONSTANDARD = 'Nonstandard'.freeze

  # Software Package Data Exchange (SPDX) standard open-source software
  # license identifiers
  IDENTIFIERS = %w(
      #{licenses.sort.join "\n      "}
  ).freeze

  REGEXP = %r{
    \\A
    (
      \#{Regexp.union(IDENTIFIERS)}
      \\+?
      (\\s WITH \\s .+)?
      | \#{NONSTANDARD}
    )
    \\Z
  }ox.freeze

  def self.match?(license)
    !REGEXP.match(license).nil?
  end
end
  RUBY
end
