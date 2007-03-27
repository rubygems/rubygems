module Gem
  module Commands
    class SpecificationCommand < Command
      include VersionOption
      include LocalRemoteOptions
      include CommandAids
    
      def initialize
        super('specification', 'Display gem specification (in yaml)',
              {:domain=>:local, :version=>"> 0.0.0"})
        add_version_option('examine')
        add_local_remote_options
        add_option('--all', 'Output specifications for all versions of',
                   'the gem') do |value, options|
          options[:all] = true
        end
      end

      def defaults_str
        "--local --version '(latest)'"
      end

      def usage
        "#{program_name} GEMFILE"
      end

      def arguments
        "GEMFILE       Name of a .gem file to examine"
      end

      def execute
        if local?
          gem = get_one_gem_name
          gem_specs = Gem::SourceIndex.from_installed_gems.search(gem, options[:version])
          unless gem_specs.empty?
            require 'yaml'
            output = lambda { |spec| say spec.to_yaml; say "\n" }
            if options[:all]
              gem_specs.each(&output)
            else
              spec = gem_specs.sort_by { |spec| spec.version }.last
              output[spec]
            end
          else
            alert_error "Unknown gem #{gem}"
          end
        end
      
        if remote?
          say "(Remote 'info' operation is not yet implemented.)"
          # NOTE: when we do implement remote info, make sure we don't
          # duplicate huge swabs of local data.  If it's the same, just
          # say it's the same.
        end
      end
    end
  end
end