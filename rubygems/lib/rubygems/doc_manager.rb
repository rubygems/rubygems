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
    
    def generate_rdoc
      require 'fileutils'

      if @spec.has_rdoc then
        load_rdoc
        install_ri # RDoc bug, ri goes first
        install_rdoc
      end

      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
    end

    def load_rdoc
      Gem::FilePermissionError.new(@doc_dir) if File.exist?(@doc_dir) && !File.writable?(@doc_dir)
      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
      begin
        require 'rdoc/rdoc'
      rescue LoadError => e
        raise DocumentError, "ERROR: RDoc documentation generator not installed!"
      end
    end

    def install_rdoc
      say "Installing RDoc documentation for #{@spec.full_name}..."
      begin
        run_rdoc '--op', File.join(@doc_dir, 'rdoc')
      rescue RDoc::RDocError => e
        raise DocumentError, e.message
      end
    end

    def install_ri
      say "Installing ri documentation for #{@spec.full_name}..."
      begin
        run_rdoc '--ri', '--op', File.join(@doc_dir, 'ri')
      rescue RDoc::RDocError => e
        raise DocumentError, e.message
      end
    end

    def run_rdoc(*args)
      args << @spec.rdoc_options
      args << DocManager.configured_args
      args << '--quiet'
      args << @spec.require_paths.clone
      args << @spec.extra_rdoc_files
      args.flatten!

      r = RDoc::RDoc.new

      old_pwd = Dir.pwd
      Dir.chdir @spec.full_gem_path
      begin
        r.document args
      rescue Errno::EACCES => e
        dirname = File.dirname e.message.split("-")[1].strip
        raise Gem::FilePermissionError.new(dirname)
      ensure
        Dir.chdir old_pwd
      end
    end

    def uninstall_doc
      doc_dir = File.join(@spec.installation_path, "doc", @spec.full_name)
      FileUtils.rm_rf doc_dir
      ri_dir = File.join(@spec.installation_path, "ri", @spec.full_name)
      FileUtils.rm_rf ri_dir
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
