require 'rubygems/indexer'

# Construct the master Gem index file.
class Gem::Indexer::MasterIndexBuilder < Gem::Indexer::AbstractIndexBuilder

  def initialize(filename, options)
    @filename = filename
    @options = options
    @directory = options[:directory]
    @enabled = true
  end

  def start_index
    super
    @file.puts "--- !ruby/object:Gem::Cache"
    @file.puts "gems:"
  end

  def cleanup
    super
    index_file_name = File.join @directory, @filename
    compress index_file_name, "Z"
    paranoid index_file_name, "#{index_file_name}.Z"
  end

  def add(spec)
    @file.puts "  #{spec.full_name}: #{nest(spec.to_yaml)}"
  end

  def nest(yaml_string)
    yaml_string[4..-1].gsub(/\n/, "\n    ")
  end

  private

  def paranoid(fn, compressed_fn)
    data = File.read fn
    compressed_data = File.read compressed_fn
    if data != unzip(compressed_data) then
      fail "Compressed file #{compressed_fn} does not match uncompressed file #{fn}"
    end
  end

end
