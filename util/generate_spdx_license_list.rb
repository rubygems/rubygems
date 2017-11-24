# frozen_string_literal: true
require 'json'
require 'uri'
require 'net/http'

uri = URI('https://spdx.org/licenses/licenses.json')
json = Net::HTTP.get(uri)
licenses = JSON.parse(json)['licenses'].map do |license_object|
  license_object['licenseId']
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

  def self.valid?(license)
    if license.length > 64
      raise Gem::InvalidSpecificationException,
        "each license must be 64 characters or less"
    end
    match?(license)
  end

  def self.match?(license)
    !REGEXP.match(license).nil?
  end

  def self.warning_for(license)
    message = <<-warning
license value '\#{license}' is invalid.  Use a license identifier from
http://spdx.org/licenses or '\#{NONSTANDARD}' for a nonstandard license.
    warning
    suggestions = suggestions(license)
    message += "Did you mean \#{suggestions.map { |s| "'\#{s}'"}.join(', ')}?\n" if suggestions
    message
  end

  def self.suggestions(license)
    by_distance = IDENTIFIERS.group_by do |identifier|
      levenshtein_distance(identifier, license)
    end
    lowest = by_distance.keys.min
    return unless lowest < license.size
    by_distance[lowest]
  end

  def self.warning_about_empty_licenses
    <<-warning
licenses is empty, but is recommended.  Use a license identifier from
http://spdx.org/licenses or '\#{NONSTANDARD}' for a nonstandard license.
    warning
  end

end
  RUBY
end
