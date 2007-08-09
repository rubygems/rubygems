require 'rubygems/command'
require 'rubygems/local_remote_options'
require 'rubygems/source_info_cache'

class Gem::Commands::QueryCommand < Gem::Command

  include Gem::LocalRemoteOptions

  def initialize(name = 'query',
                 summary = 'Query gem information in local or remote repositories')
    super name, summary,
         :name => /.*/, :domain => :local, :details => false, :versions => true

    add_option('-n', '--name-matches REGEXP',
               'Name of gem(s) to query on matches the',
               'provided REGEXP') do |value, options|
      options[:name] = /#{value}/i
    end

    add_option('-d', '--[no-]details',
               'Display detailed information of gem(s)') do |value, options|
      options[:details] = value
    end

    add_option(      '--[no-]versions',
               'Display only gem names') do |value, options|
      options[:versions] = value
      options[:details] = false unless value
    end

    add_local_remote_options
  end

  def defaults_str
    "--local --name-matches '.*' --no-details --versions"
  end

  def execute
    name = options[:name]

    if local? then
      say
      say "*** LOCAL GEMS ***"
      output_query_results Gem.cache.search(name)
    end

    if remote? then
      say
      say "*** REMOTE GEMS ***"
      output_query_results Gem::SourceInfoCache.search(name)
    end
  end

  private

  def output_query_results(gemspecs)
    gem_list_with_version = {}

    gemspecs.flatten.each do |gemspec|
      gem_list_with_version[gemspec.name] ||= []
      gem_list_with_version[gemspec.name] << gemspec
    end

    gem_list_with_version = gem_list_with_version.sort do |first, second|
      first[0].downcase <=> second[0].downcase
    end

    gem_list_with_version.each do |gem_name, list_of_matching|
      say if options[:versions]
      list_of_matching = list_of_matching.sort_by { |x| x.version }.reverse
      seen_versions = []

      list_of_matching.delete_if do |item|
        if seen_versions.member?(item.version) then
          true
        else
          seen_versions << item.version
          false
        end
      end

      entry = gem_name.dup
      if options[:versions] then
        entry << " (#{list_of_matching.map{|gem| gem.version.to_s}.join(", ")})"
      end

      say entry
      say format_text(list_of_matching[0].summary, 68, 4) if options[:details]
    end
  end

  ##
  # Used for wrapping and indenting text
  #
  def format_text(text, wrap, indent=0)
    result = []
    work = text.dup

    while work.length > wrap
      if work =~ /^(.{0,#{wrap}})[ \n]/o then
        result << $1
        work.slice!(0, $&.length)
      else
        result << work.slice!(0, wrap)
      end
    end

    result << work if work.length.nonzero?
    result.join("\n").gsub(/^/, " " * indent)
  end

end

