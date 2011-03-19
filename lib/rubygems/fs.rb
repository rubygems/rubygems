require 'rubygems/path'

##
#
# Gem::FS is the representation of the RubyGems filesystem structure, which
# typically consists of several directories:
#
#   - GEM_HOME
#   |- gems
#   |- doc
#   |- cache
#   |- specifications
#   |- bin
#
# gems:: the directory where unpacked gems are stored, has an internal structure of gem_name-version.
# cache:: the gem files as they are downloaded from sources like rubygems.org.
# specifications:: specification files (.gemspec) that correspond to the gems installed in `gems'.
# doc:: documentation related to the gems installed in `gems'.
# bin:: command-line scripts related to gems installed in `gems'.
#
# Gem::FS inherits from Gem::Path, including its constructor. 
# 
class Gem::FS < Gem::Path
  ##
  # Default directories in a gem repository

  DIRECTORIES = %w[cache doc gems specifications] unless defined?(DIRECTORIES)

  ##
  # Quietly ensure the named Gem directory contains all the proper
  # subdirectories, named in Gem::FS::DIRECTORIES.  If we can't create a directory due
  # to a permission problem, then we will silently continue.

  def ensure_gem_subdirectories
    require 'fileutils'

    DIRECTORIES.each do |name|
      fn = send(name)
      FileUtils.mkdir_p fn rescue nil unless File.exist? fn
    end
  end

  ##
  # Return the bin path as a Gem::Path
  def bin
    Gem::Path.new(path, 'bin')
  end

  ##
  # Return the cache path as a Gem::Path
  def cache
    Gem::Path.new(path, 'cache')
  end

  ##
  # Return the specifications path as a Gem::Path
  def specifications
    Gem::Path.new(path, 'specifications')
  end
  
  ##
  # Return the gems path as a Gem::Path
  def gems
    Gem::Path.new(path, 'gems')
  end

  ##
  # Return the doc path as a Gem::Path
  def doc
    Gem::Path.new(path, 'doc')
  end
  
  ##
  # Return the source_cache path as a Gem::Path
  def source_cache
    Gem::Path.new(path, 'source_cache')
  end
end
