require 'rubygems/command'
require 'rubygems/local_remote_options'
require 'rubygems/source_index'
require 'rubygems/source_info_cache'

module Gem
  module Commands

    class OutdatedCommand < Command

      include Gem::LocalRemoteOptions

      def initialize
        super 'outdated', 'Display all gems that need updates'

        add_local_remote_options
      end

      def execute
        locals = Gem::SourceIndex.from_installed_gems
        locals.outdated.each do |name|
          local = locals.search(/^#{name}$/).last
          remote = Gem::SourceInfoCache.search(/^#{name}$/).last
          say "#{local.name} (#{local.version} < #{remote.version})"
        end
      end

    end
  end
end
