module Gem
  
  class DocManager
    
    def self.install_doc(spec, install_rdoc)
      doc_dir = File.join(spec.installation_path, "doc", spec.full_name)
      if install_rdoc
        puts "Installing RDoc documentation for #{spec.full_name}"
        require 'rdoc/rdoc'
        begin
          source_dirs = spec.require_paths.collect {|req| File.join(spec.installation_path, spec.full_name, req)}
          r = RDoc::RDoc.new
          r.document(['--op', doc_dir, '--template', 'kilmer'] + source_dirs)
        rescue RDoc::RDocError => e
          $stderr.puts e.message
        end
      end
    end
    
    def self.uninstall_doc(spec)
      doc_dir = File.join(spec.installation_path, "doc", spec.full_name)
      require 'fileutils'
      FileUtils.rm_rf doc_dir
    end
    
  end
end
