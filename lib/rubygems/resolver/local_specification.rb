class Gem::Resolver::LocalSpecification < Gem::Resolver::SpecSpecification

  ##
  # Installs this gem using +options+.  Yields the installer instance before
  # installation begins.

  def install options
    require 'rubygems/installer'

    destination = options[:install_dir] || Gem.dir

    Gem.ensure_gem_subdirectories destination

    gem = source.download spec, destination

    installer = Gem::Installer.new gem, options

    yield installer if block_given?

    installer.install
  end

  ##
  # Returns +true+ if this gem is installable for the current platform.

  def installable_platform?
    return true if @source.kind_of? Gem::Source::SpecificFile

    super
  end

end

