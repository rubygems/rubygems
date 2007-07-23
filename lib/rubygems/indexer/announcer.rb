require 'rubygems/indexer'

# Announcer provides a way of announcing activities to the user.
module Gem::Indexer::Announcer # HACK Gem::UserInteraction?

  # Announce +msg+ to the user.
  def announce(msg)
    puts msg if @options[:verbose]
  end

end

