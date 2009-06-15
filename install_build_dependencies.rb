#!/usr/bin/env ruby
# Installs dependencies required to test and build RubyGems itself.

require 'rubygems'
puts 'Installing/upgrading minitest, hoe, and hoe-seattlerb gems if necessary...'
puts `gem install minitest` unless Gem.available?(/^minitest$/,'>=1.3.1')
puts `gem install hoe` unless Gem.available?(/^hoe$/,'>=2.1.0')
puts `gem install hoe-seattlerb` unless Gem.available?(/^hoe-seattlerb$/,'>=1.0.0')
