module Gem

  class DocumentError < Gem::Exception; end
  
  class DocManager
  
    include UserInteraction
  
    #
    # spec::      The Gem::Specification object representing the gem.
    # rdoc_args:: Optional arguments for RDoc (template etc.) as a String.
    #
    def initialize(spec, rdoc_args="")
      @spec = spec
      @doc_dir = File.join(spec.installation_path, "doc", spec.full_name)
      Gem::FilePermissionError.new(spec.installation_path) unless File.writable?(spec.installation_path)
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

    ##
    # Return Rdoc args as specified in gem spec.  If args exist in gemspec,
    # append any user-defined args.  This behavior is open for a vote. 
    def rdoc_args_from_spec(non_spec_args)
      @spec.rdoc_options << non_spec_args 
    end
    
    def generate_rdoc
      return if @spec.has_rdoc == false
      require 'fileutils'
      Gem::FilePermissionError.new(@doc_dir) if File.exist?(@doc_dir) && !File.writable?(@doc_dir)
      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
      begin
        require 'rdoc/rdoc'
      rescue LoadError => e
        raise DocumentError, "ERROR: RDoc documentation generator not installed!"
      end
      say "Installing RDoc documentation for #{@spec.full_name}..."
      rdoc_dir = File.join(@doc_dir, "rdoc")
      begin
        source_dirs = @spec.require_paths.clone.concat(@spec.extra_rdoc_files)
        current_dir = Dir.pwd
        Dir.chdir(@spec.full_gem_path)
        begin
          @rdoc_args = rdoc_args_from_spec(@rdoc_args)
          @rdoc_args.concat(DocManager.configured_args)
          r = RDoc::RDoc.new
          begin
            r.document(['--quiet', '--op', rdoc_dir] + @rdoc_args.flatten + source_dirs)
          rescue Errno::EACCES => e
            raise Gem::FilePermissionError.new(File.dirname(e.message.split("-")[1].strip))
          end
	 #TODO: Why is this throwing an error?
          #ri = RDoc::RDoc.new
          #ri.document(['-R'] + source_dirs)
        ensure
          Dir.chdir(current_dir)
        end
      rescue RDoc::RDocError => e
        raise DocumentError, e.message
      end
    end
    
    def uninstall_doc
      doc_dir = File.join(@spec.installation_path, "doc", @spec.full_name)
      FileUtils.rm_rf doc_dir
    end

    class << self
      def configured_args
        @configured_args ||= []
      end

      def configured_args=(args)
        case args
        when Array
          @configured_args = args
        when String
          @configured_args = args.split
        end
      end
    end
    
  end
end
