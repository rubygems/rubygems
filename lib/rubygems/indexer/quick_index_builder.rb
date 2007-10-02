require 'rubygems/indexer'

# Construct a quick index file and all of the individual specs to support
# incremental loading.
class Gem::Indexer::QuickIndexBuilder < Gem::Indexer::AbstractIndexBuilder

  def initialize(filename, directory)
    directory = File.join directory, 'quick'
    super filename, directory
  end

  def cleanup
    super

    quick_index_file = File.join(@directory, @filename)
    compress quick_index_file

    # the complete quick index is in a directory, so move it as a whole
    @files.delete quick_index_file
    @files << @directory
  end

  def add(spec)
    @file.puts spec.full_name
    add_yaml(spec)
    add_marshal(spec)
  end

  def add_yaml(spec)
    fn = File.join @directory, "#{spec.full_name}.gemspec.rz"
    zipped = zip spec.to_yaml
    File.open fn, "wb" do |gsfile| gsfile.write zipped end
  end

  def add_marshal(spec)
    fn = File.join @directory, "#{spec.full_name}.gemspec.marshal.#{Gem.marshal_version}.rz"
    zipped = zip Marshal.dump(spec)
    File.open fn, "wb" do |gsfile| gsfile.write zipped end
  end

end

