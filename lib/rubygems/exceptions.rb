require 'rubygems'

module Gem

  ##
  # Signals that local installation will not proceed, not that it has been
  # tried and failed.
  #--
  # TODO: better name.
  class LocalInstallationError < Gem::Exception; end

  ##
  # Signals that a file permission error is preventing the user from
  # installing in the requested directories.
  class FilePermissionError < Gem::Exception
    def initialize(path)
      super("You don't have write permissions into the #{path} directory.")
    end
  end

  ##
  # Signals that a remote operation cannot be conducted, probably due to not
  # being connected (or just not finding host).
  #--
  # TODO: create a method that tests connection to the preferred gems server.
  # All code dealing with remote operations will want this.  Failure in that
  # method should raise this error.
  class RemoteError < Gem::Exception; end

  # Potentially raised when a specification is validated.
  class InvalidSpecificationException < Gem::Exception; end

  # Potentially raised when a specification is validated.
  class EndOfYAMLException < Gem::Exception; end

end

