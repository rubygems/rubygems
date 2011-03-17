require 'rubygems/path'

module Gem
  class FS < Gem::Path
    ##
    # Default directories in a gem repository

    DIRECTORIES = %w[cache doc gems specifications] unless defined?(DIRECTORIES)

    ##
    # Quietly ensure the named Gem directory contains all the proper
    # subdirectories.  If we can't create a directory due to a permission
    # problem, then we will silently continue.

    def ensure_gem_subdirectories
      require 'fileutils'

      DIRECTORIES.each do |name|
        fn = send(name)
        FileUtils.mkdir_p fn rescue nil unless File.exist? fn
      end
    end

    def bin
      path.add 'bin'
    end

    def cache
      path.add 'cache'
    end

    def specifications
      path.add 'specifications'
    end

    def gems
      path.add 'gems'
    end

    def doc
      path.add 'doc'
    end

    def source_cache
      path.add 'source_cache'
    end
  end
end
