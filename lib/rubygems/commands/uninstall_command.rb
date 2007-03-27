module Gem
  module Commands
    class UninstallCommand < Command
      include VersionOption
      include CommandAids

      def initialize
        super('uninstall', 'Uninstall gems from the local repository',
              { :version => "> 0" })

        add_option('-a', '--[no-]all',
          'Uninstall all matching versions'
          ) do |value, options|
          options[:all] = value
        end

          add_option('-i', '--[no-]ignore-dependencies',
                     'Ignore dependency requirements while',
                     'uninstalling') do |value, options|
          options[:ignore] = value
        end

          add_option('-x', '--[no-]executables',
                     'Uninstall applicable executables without',
                     'confirmation') do |value, options|
          options[:executables] = value
        end

        add_version_option('uninstall')
      end

      def defaults_str
        "--version '> 0' --no-force"
      end
    
      def usage
        "#{program_name} GEMNAME [GEMNAME ...]"
      end

      def arguments
        "GEMNAME   name of gem to uninstall"
      end

      def execute
        get_all_gem_names.each do |gem_name|
          Gem::Uninstaller.new(gem_name, options).uninstall
        end
      end
    end
  end
end