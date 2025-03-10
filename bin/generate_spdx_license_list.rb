# frozen_string_literal: true
require 'json'
require 'net/http'
require 'uri'

licenses_json = Net::HTTP.get(URI('https://spdx.org/licenses/licenses.json'))
licenses = JSON.parse(licenses_json)['licenses'].map do |licenseObject|
  licenseObject['licenseId']
end
exceptions_json = Net::HTTP.get(URI('https://spdx.org/licenses/exceptions.json'))
exceptions = JSON.parse(exceptions_json)['exceptions'].map do |exceptionObject|
  exceptionObject['licenseExceptionId']
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
  LICENSE_IDENTIFIERS = %w(
    #{licenses.sort.join "\n    "}
  ).freeze

  # exception identifiers
  EXCEPTION_IDENTIFIERS = %w(
    #{exceptions.sort.join "\n    "}
  ).freeze

  REGEXP = %r{
    \\A
    (
      \#{Regexp.union(LICENSE_IDENTIFIERS)}
      \\+?
      (\\s WITH \\s \#{Regexp.union(EXCEPTION_IDENTIFIERS)})?
      | \#{NONSTANDARD}
    )
    \\Z
  }ox.freeze

  def self.match?(license)
    !REGEXP.match(license).nil?
  end

  def self.suggestions(license)
    by_distance = LICENSE_IDENTIFIERS.group_by do |identifier|
      levenshtein_distance(identifier, license)
    end
    lowest = by_distance.keys.min
    return unless lowest < license.size
    by_distance[lowest]
  end

end
  RUBY
end
