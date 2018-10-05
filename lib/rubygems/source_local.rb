# frozen_string_literal: true
require_relative 'source'
require_relative 'source_local'

unless Gem::Deprecate.skip
  Kernel.warn "#{Gem.location_of_caller(3).join(':')}: Warning: Requiring rubygems/source_local is deprecated; please use rubygems/source/local instead."
end

