#!/usr/bin/env ruby

require 'fileutils'
require 'test/yaml_data'

module Utilities
  def make_gemhome(path)
    FileUtils.mkdir_p path
  end

  def make_cache_area(path, *uris)
    make_gemhome(path)
    fn = File.join(path, 'source_cache')
    open(fn, 'w') do |f| f.write cache_hash(*uris).to_yaml end
  end

  extend self
end
