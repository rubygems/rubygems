module Gem
  
  class DocManager
  
    #
    # spec::      The Gem::Specification object representing the gem.
    # rdoc_args:: Optional arguments for RDoc (template etc.) as a String.
    #
    def initialize(spec, rdoc_args="")
      @spec = spec
      @doc_dir = File.join(spec.installation_path, "doc", spec.full_name)
      @rdoc_args = rdoc_args.nil? ? [] : rdoc_args.split
    end
    
    def rdoc_installed?
      return File.exist?(File.join(@doc_dir, "rdoc"))
    end
    
    def install_doc(rdoc = true)
      self.generate_rdoc if rdoc
      require 'fileutils'
      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
    end
    
    def generate_rdoc
      require 'fileutils'
      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
      begin
        require 'rdoc/rdoc'
      rescue LoadError => e
        puts "ERROR: RDoc documentation generator not installed!"
        puts "       To install RDoc:  gem --remote-install=rdoc"
        return
      end
      puts "Installing RDoc documentation for #{@spec.full_name}..."
      puts "WARNING: Generating RDoc on .gem that may not have RDoc." unless @spec.has_rdoc?
      rdoc_dir = File.join(@doc_dir, "rdoc")
      begin
        source_dirs = @spec.require_paths.collect do |req|         
          path = File.join(@spec.full_gem_path, req)
          path = path[2..-1] if path =~ /^[a-zA-Z]\:/
          path
        end
        r = RDoc::RDoc.new
        r.document(['--op', rdoc_dir, '--template', 'kilmer'] + @rdoc_args.flatten + source_dirs)
      rescue RDoc::RDocError => e
        $stderr.puts e.message
      end
    end
    
    def uninstall_doc
      doc_dir = File.join(@spec.installation_path, "doc", @spec.full_name)
      FileUtils.rm_rf doc_dir
    end
    
  end
end
