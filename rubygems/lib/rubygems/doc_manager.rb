#--
# Copyright 2006 by Chad Fowler, Rich Kilmer, Jim Weirich and others.
# All rights reserved.
# See LICENSE.txt for permissions.
#++

module Gem

  class DocumentError < Gem::Exception; end
  
  class DocManager
  
    include UserInteraction
  
    # Create a document manager for the given gem spec.
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
    
    # Is the RDoc documentation installed?
    def rdoc_installed?
      return File.exist?(File.join(@doc_dir, "rdoc"))
    end
    
    # Generate the RI documents for this gem spec.
    #
    # Note that if both RI and RDoc documents are generated from the
    # same process, the RI docs should be done first (a likely bug in
    # RDoc will cause RI docs generation to fail if run after RDoc).
    def generate_ri
      require 'fileutils'

      if @spec.has_rdoc then
        load_rdoc
        install_ri # RDoc bug, ri goes first
      end

      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
    end

    # Generate the RDoc documents for this gem spec.
    #
    # Note that if both RI and RDoc documents are generated from the
    # same process, the RI docs should be done first (a likely bug in
    # RDoc will cause RI docs generation to fail if run after RDoc).
    def generate_rdoc
      require 'fileutils'

      if @spec.has_rdoc then
        load_rdoc
        install_rdoc
      end

      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
    end

    # Load the RDoc documentation generator library.
    def load_rdoc
      if File.exist?(@doc_dir) && !File.writable?(@doc_dir)
        Gem::FilePermissionError.new(@doc_dir)
      end
      FileUtils.mkdir_p @doc_dir unless File.exist?(@doc_dir)
      begin
        require 'rdoc/rdoc'
      rescue LoadError => e
        raise DocumentError, 
          "ERROR: RDoc documentation generator not installed!"
      end
    end

    def install_rdoc
      say "Installing RDoc documentation for #{@spec.full_name}..."
      run_rdoc '--op', File.join(@doc_dir, 'rdoc')
    end

    def install_ri
      say "Installing ri documentation for #{@spec.full_name}..."
      run_rdoc '--ri', '--op', File.join(@doc_dir, 'ri')
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
      Dir.chdir(@spec.full_gem_path)
      begin
        r.document args
      rescue Errno::EACCES => e
        dirname = File.dirname e.message.split("-")[1].strip
        raise Gem::FilePermissionError.new(dirname)
      rescue RuntimeError => ex
        STDERR.puts "While generating documentation for #{@spec.full_name}"
        STDERR.puts "... MESSAGE:   #{ex}"
        STDERR.puts "... RDOC args: #{args.join(' ')}"
        STDERR.puts ex.backtrace if Gem.configuration.backtrace
        STDERR.puts "(continuing with the rest of the installation)"
      ensure
        Dir.chdir(old_pwd)
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
