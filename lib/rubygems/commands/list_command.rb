module Gem
  module Commands
    class ListCommand < QueryCommand
      include CommandAids

      def initialize
        super(
          'list',
          'Display all gems whose name starts with STRING'
        )
        remove_option('--name-matches')
      end

      def defaults_str
        "--local --no-details"
      end

      def usage
        "#{program_name} [STRING]"
      end

      def arguments
        "STRING   start of gem name to look for"
      end

      def execute
        string = get_one_optional_argument || ''
        options[:name] = /^#{string}/i
        super
      end
    end
  end
end