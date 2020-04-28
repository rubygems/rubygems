# frozen_string_literal: true

$LOAD_PATH.reject! { |lp| lp =~ /site_ruby|vendor_ruby/ }

require "rubygems"

print Gem::VERSION
