require 'rubygems/indexer'

# Top level class for building the repository index.  Initialize with
# an options hash and call +build_index+.
class Gem::Indexer::Indexer
  include Gem::Indexer::Compressor
  include Gem::UserInteraction

  # Create an indexer with the options specified by the options hash.
  def initialize(options)
    @options = options.dup
    @directory = @options[:directory]
    @options[:quick_directory] = File.join @directory, "quick"
    @master_index = Gem::Indexer::MasterIndexBuilder.new "yaml", @options
    @quick_index = Gem::Indexer::QuickIndexBuilder.new "index", @options
  end

  # Build the index.
  def build_index
    FileUtils.rm_r(@options[:quick_directory]) rescue nil

    @master_index.build do
      @quick_index.build do
        progress = ui.progress_reporter gem_file_list.size,
                                       "Generating index for #{gem_file_list.size} files in #{@options[:directory]}"

        gem_file_list.each do |gemfile|
          #say "Handling #{gemfile}"
          if File.size(gemfile.to_s) == 0 then
            alert_warning "Skipping zero-length gem: #{gemfile}"
            next
          end

          begin
            spec = Gem::Format.from_file_by_path(gemfile).spec

            unless gemfile =~ /\/#{spec.full_name}.*\.gem\z/i then
              alert_warning "Skipping misnamed gem: #{gemfile} => #{spec.full_name}"
              next
            end

            abbreviate spec
            sanitize spec

            @master_index.add spec
            @quick_index.add spec

            progress.updated spec.full_name

          rescue Exception => e
            alert_error "Unable to process #{gemfile}\n#{e.message}\n\t#{e.backtrace.join "\n\t"}"
          end
        end

        progress.done
      end
    end
  end

  # List of gem file names to index.
  def gem_file_list
    Dir.glob(File.join(@directory, "gems", "*.gem"))
  end

  # Abbreviate the spec for downloading.  Abbreviated specs are only
  # used for searching, downloading and related activities and do not
  # need deployment specific information (e.g. list of files).  So we
  # abbreviate the spec, making it much smaller for quicker downloads.
  def abbreviate(spec)
    spec.files = []
    spec.test_files = []
    spec.rdoc_options = []
    spec.extra_rdoc_files = []
    spec.cert_chain = []
    spec
  end

  # Sanitize the descriptive fields in the spec.  Sometimes non-ASCII
  # characters will garble the site index.  Non-ASCII characters will
  # be replaced by their XML entity equivalent.
  def sanitize(spec)
    spec.summary = sanitize_string(spec.summary)
    spec.description = sanitize_string(spec.description)
    spec.post_install_message = sanitize_string(spec.post_install_message)
    spec.authors = spec.authors.collect { |a| sanitize_string(a) }
    spec
  end

  # Sanitize a single string.
  def sanitize_string(string)
    # HACK the #to_s is in here because RSpec has an Array of Arrays of
    # Strings for authors.  Need a way to disallow bad values on gempsec
    # generation.  (Probably won't happen.)
    string ? string.to_s.to_xs : string
  end

end

