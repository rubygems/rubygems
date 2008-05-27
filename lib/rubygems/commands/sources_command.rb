require 'fileutils'
require 'rubygems/command'
require 'rubygems/remote_fetcher'
require 'rubygems/spec_fetcher'

class Gem::Commands::SourcesCommand < Gem::Command

  def initialize
    super 'sources',
          'Manage the sources and cache file RubyGems uses to search for gems'

    add_option '-a', '--add SOURCE_URI', 'Add source' do |value, options|
      options[:add] = value
    end

    add_option '-l', '--list', 'List sources' do |value, options|
      options[:list] = value
    end

    add_option '-r', '--remove SOURCE_URI', 'Remove source' do |value, options|
      options[:remove] = value
    end

    add_option '-c', '--clear-all',
               'Remove all sources (clear the cache)' do |value, options|
      options[:clear_all] = value
    end
  end

  def defaults_str
    '--list'
  end

  def execute
    options[:list] = !(options[:add] || options[:remove] || options[:clear_all])

    if options[:clear_all] then
      path = Gem::SpecFetcher.fetcher.dir
      FileUtils.rm_rf path

      if not File.exist?(path) then
        say "*** Removed source cache ***"
      elsif not File.writable?(path) then
        say "*** Unable to remove source cache (write protected) ***"
      else
        say "*** Unable to remove source cache ***"
      end
    end

    if options[:add] then
      source_uri = options[:add]

      begin
        Gem::SpecFetcher.fetcher.load_specs URI.parse(source_uri), 'specs'
        Gem.sources << source_uri
        Gem.configuration.write

        say "#{source_uri} added to sources"
      rescue URI::Error, ArgumentError
        say "#{source_uri} is not a URI"
      rescue Gem::RemoteFetcher::FetchError => e
        say "Error fetching #{source_uri}:\n\t#{e.message}"
      end
    end

    if options[:remove] then
      source_uri = options[:remove]

      unless Gem.sources.include? source_uri then
        say "source #{source_uri} not present in cache"
      else
        Gem.sources.delete source_uri
        Gem.configuration.write

        say "#{source_uri} removed from sources"
      end
    end

    if options[:list] then
      say "*** CURRENT SOURCES ***"
      say

      Gem.sources.each do |source|
        say source
      end
    end
  end

end

