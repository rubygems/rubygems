require 'rubygems/indexer'

# Construct a quick index file and all of the individual specs to support
# incremental loading.
class Gem::Indexer::QuickIndexBuilder < Gem::Indexer::AbstractIndexBuilder

  def initialize(filename, options)
    @filename = filename
    @options = options
    @directory = options[:quick_directory]
    @enabled = options[:quick]
  end

  def cleanup
    compress File.join(@directory, @filename)
  end

  def add(spec)
    return unless @enabled
    @file.puts spec.full_name
    fn = File.join @directory, "#{spec.full_name}.gemspec.rz"
    File.open fn, "wb"  do |gsfile|
      gsfile.write zip(spec.to_yaml)
    end
  end

end

