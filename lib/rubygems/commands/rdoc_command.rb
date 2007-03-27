module Gem
  module Commands
    class RdocCommand < Command
      include VersionOption
      include CommandAids

      def initialize
        super('rdoc',
          'Generates RDoc for pre-installed gems',
          {
            :version => "> 0.0.0",
            :include_rdoc => true,
            :include_ri => true,
          })
        add_option('--all',
                   'Generate RDoc/RI documentation for all',
                   'installed gems') do |value, options|
          options[:all] = value
        end
        add_option('--[no-]rdoc', 
          'Include RDoc generated documents') do
          |value, options|
          options[:include_rdoc] = value
        end
        add_option('--[no-]ri', 
          'Include RI generated documents'
          ) do |value, options|
          options[:include_ri] = value
        end
        add_version_option('rdoc')
      end

      def defaults_str
        "--version '> 0.0.0' --rdoc --ri"
      end

      def usage
        "#{program_name} [args]"
      end

      def arguments
        "GEMNAME          The gem to generate RDoc for (unless --all)"
      end

      def execute
        if options[:all]
          specs = Gem::SourceIndex.from_installed_gems.collect { |name, spec|
            spec
          }
        else
          gem_name = get_one_gem_name
          specs = Gem::SourceIndex.from_installed_gems.search(
            gem_name, options[:version])
        end

        if specs.empty?
          fail "Failed to find gem #{gem_name} to generate RDoc for #{options[:version]}"
        end
        if options[:include_ri]
          specs.each do |spec|
            Gem::DocManager.new(spec).generate_ri
          end
        end
        if options[:include_rdoc]
          specs.each do |spec|
            Gem::DocManager.new(spec).generate_rdoc
          end
        end

        true
      end
    end
    
  end
end