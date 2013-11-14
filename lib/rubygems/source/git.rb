require 'digest'
require 'rubygems/util'

##
# A git gem for use in a gem dependencies file.
#
# Example:
#
#   source = Gem::Source::Git.new 'rake', 'git@example:rake.git', 'rake-10.1.0'
#
#   source.update

class Gem::Source::Git < Gem::Source

  ##
  # Creates a new git gem source for a gem with the given +name+ that will be
  # loaded from +reference+ in +repository+.

  def initialize name, repository, reference
    @name       = name
    @repository = repository
    @reference  = reference

    @git = ENV['git'] || 'git'
  end

  ##
  # Checks out the files for the repository into the install_dir.

  def checkout # :nodoc:
    unless File.exist? install_dir then
      system @git, 'clone', '--quiet', '--no-checkout',
             repo_cache_dir, install_dir
    end

    Dir.chdir install_dir do
      system @git, 'fetch', '--quiet', '--force', '--tags', install_dir
      system @git, 'reset', '--quiet', '--hard', @reference
    end
  end

  ##
  # Creates a local cache repository for the git gem.

  def cache # :nodoc:
    system @git, 'clone', '--quiet', '--bare', '--no-hardlinks',
           @repository, repo_cache_dir
  end

  ##
  # A short reference for use in git gem directories

  def dir_shortref # :nodoc:
    rev_parse[0..11]
  end

  ##
  # The directory where the git gem will be installed.

  def install_dir # :nodoc:
    File.join Gem.dir, 'bundler', 'gems', "#{@name}-#{dir_shortref}"
  end

  ##
  # The directory where the git gem's repository will be cached.

  def repo_cache_dir # :nodoc:
    File.join Gem.dir, 'cache', 'bundler', 'git', "#{@name}-#{uri_hash}"
  end

  ##
  # Converts the git reference for the repository into a commit hash.

  def rev_parse # :nodoc:
    # HACK no safe equivalent of ` exists on 1.8.7
    Dir.chdir repo_cache_dir do
      Gem::Util.popen(@git, 'rev-parse', @reference).strip
    end
  end

  ##
  # Updates the files in the git gem install directory.

  def update # :nodoc:
    if File.exist? repo_cache_dir then
      raise NotImplementedError
    else
      cache

      checkout
    end
  end

  ##
  # A hash for the git gem based on the git repository URI.

  def uri_hash # :nodoc:
    normalized =
      if @repository =~ %r%^\w+://(\w+@)?% then
        uri = URI(@repository).normalize.to_s.sub %r%/$%,''
        uri.sub(/\A(\w+)/) { $1.downcase }
      else
        @repository
      end

    Digest::SHA1.hexdigest normalized
  end

end

