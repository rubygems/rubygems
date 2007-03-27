module Gem
  module Commands

    class OutdatedCommand < Command

      def initialize
        super 'outdated', 'Display all gems that need updates'
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