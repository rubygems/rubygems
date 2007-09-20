require 'rubygems'

begin
  require 'builder/xchar'
rescue LoadError
end

module Gem::Indexer
end

require 'rubygems/indexer/compressor'
require 'rubygems/indexer/abstract_index_builder'
require 'rubygems/indexer/master_index_builder'
require 'rubygems/indexer/quick_index_builder'
require 'rubygems/indexer/indexer'

