require 'rubygems/indexer'

# Abstract base class for building gem indicies.  Uses the template pattern
# with subclass specialization in the +begin_index+, +end_index+ and +cleanup+
# methods.
class Gem::Indexer::AbstractIndexBuilder

  include Gem::Indexer::Compressor

  # Directory to put index files in
  attr_reader :directory

  # File name of the generated index
  attr_reader :filename

  # List of written files/directories to move into production
  attr_reader :files

  def initialize(filename, directory)
    @filename = filename
    @directory = directory
    @files = []
  end

  # Build a Gem index.  Yields to block to handle the details of the
  # actual building.  Calls +begin_index+, +end_index+ and +cleanup+ at
  # appropriate times to customize basic operations.
  def build
    FileUtils.mkdir_p @directory unless File.exist? @directory
    raise "not a directory: #{@directory}" unless File.directory? @directory

    file_path = File.join @directory, @filename

    @files << file_path

    File.open file_path, "wb" do |file|
      @file = file
      start_index
      yield
      end_index
    end
    cleanup
  ensure
    @file = nil
  end

  # Called immediately before the yield in build.  The index file is open and
  # available as @file.
  def start_index
  end

  # Called immediately after the yield in build.  The index file is still open
  # and available as @file.
  def end_index
  end

  # Called from within builder after the index file has been closed.
  def cleanup
  end

end

