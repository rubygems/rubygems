module Gem
  
  class DocManager
  
    def initialize(spec)
      @spec = spec
      @doc_dir = File.join(spec.installation_path, "doc", spec.full_name)
      require 'fileutils'
      FileUtils.mkdir_p @doc_dir
    end
    
    def install_doc(rdoc = true)
      self.generate_rdoc if rdoc
    end
    
    def generate_rdoc
      begin
        require 'rdoc/rdoc'
      rescue LoadError => e
        puts "ERROR: RDoc documentation generator not installed!"
        puts "       To download perform: "
        puts "         gem --remote-install=rdoc"
        return
      end
      puts "Installing RDoc documentation for #{@spec.full_name}..."
      puts "WARNING: Generating RDoc on .gem that may not have RDoc." unless @spec.has_rdoc?
      rdoc_dir = File.join(@doc_dir, "rdoc")
      begin
        source_dirs = @spec.require_paths.collect {|req| File.join(@spec.installation_path, @spec.full_name, req)}
        r = RDoc::RDoc.new
        r.document(['--op', rdoc_dir, '--template', 'kilmer'] + source_dirs)
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
