# frozen_string_literal: true
require 'json'
require 'net/http'
require 'uri'

licenses_json = Net::HTTP.get(URI('https://spdx.org/licenses/licenses.json'))
licenses = JSON.parse(licenses_json)['licenses'].map do |licenseObject|
  "\n      '#{licenseObject['licenseId']}' => #{licenseObject['isDeprecatedLicenseId']},"
end
exceptions_json = Net::HTTP.get(URI('https://spdx.org/licenses/exceptions.json'))
exceptions = JSON.parse(exceptions_json)['exceptions'].map do |exceptionObject|
  "\n      '#{exceptionObject['licenseExceptionId']}' => #{exceptionObject['isDeprecatedLicenseId']},"
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
  # values in this hash mean deprecation status(deprecated if true).
  LICENSE_IDENTIFIERS = {#{licenses.sort.join}
  }.freeze

  # exception identifiers
  # values in this hash mean deprecation status(deprecated if true).
  EXCEPTION_IDENTIFIERS = {#{exceptions.sort.join}
  }.freeze

  REGEXP = %r{
    \\A
    (?:
      (?<license>
        \#{Regexp.union(LICENSE_IDENTIFIERS.keys)}
      )\\+?
      (?:\\s WITH \\s 
        (?<exception>
          \#{Regexp.union(EXCEPTION_IDENTIFIERS.keys)}
        )
      )? | \#{NONSTANDARD}
    )
    \\Z
  }ox.freeze

  def self.match?(license)
    !REGEXP.match(license).nil?
  end

  def self.deprecated?(license)
    match = REGEXP.match(license)
    return unless match
    cap = match.names.map {|n| [n, match[n]]}.to_h
    (cap['license'] && LICENSE_IDENTIFIERS[cap['license']])\\
    || (cap['exception'] && EXCEPTION_IDENTIFIERS[cap['exception']])
  end

  def self.suggestions(license)
    by_distance = LICENSE_IDENTIFIERS.reject { |_, v| v }.keys.group_by do |identifier|
      levenshtein_distance(identifier, license)
    end
    lowest = by_distance.keys.min
    return unless lowest < license.size
    by_distance[lowest]
  end
end
  RUBY
end
