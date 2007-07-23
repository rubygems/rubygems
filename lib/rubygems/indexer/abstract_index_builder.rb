require 'rubygems/indexer'

# Abstract base class for building gem indicies.  Uses the template pattern
# with subclass specialization in the +begin_index+, +end_index+ and +cleanup+
# methods.
class Gem::Indexer::AbstractIndexBuilder

  include Gem::Indexer::Compressor

  # Build a Gem index.  Yields to block to handle the details of the
  # actual building.  Calls +begin_index+, +end_index+ and +cleanup+ at
  # appropriate times to customize basic operations.
  def build
    unless @enabled then
      yield
    else
      FileUtils.mkdir_p @directory unless File.exist? @directory

      fail "not a directory: #{@directory}" unless File.directory? @directory

      File.open File.join(@directory, @filename), "wb" do |file|
        @file = file
        start_index
        yield
        end_index
      end
      cleanup
    end
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

