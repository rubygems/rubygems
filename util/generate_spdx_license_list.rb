# frozen_string_literal: true
require 'json'
require 'net/http'
require 'uri'

json = Net::HTTP.get(URI('https://spdx.org/licenses/licenses.json'))
licenses = JSON.parse(json)['licenses'].map do |licenseObject|
  licenseObject['licenseId']
end

open 'lib/rubygems/util/licenses.rb', 'w' do |io|
  io.write <<-RUBY
# frozen_string_literal: true
require 'rubygems/text'

class Gem::Licenses
  extend Gem::Text

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

  def self.suggestions(license)
    by_distance = IDENTIFIERS.group_by do |identifier|
      levenshtein_distance(identifier, license)
    end
    lowest = by_distance.keys.min
    return unless lowest < license.size
    by_distance[lowest]
  end
end
  RUBY
end
