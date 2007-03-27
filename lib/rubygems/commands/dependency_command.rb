module Gem
  module Commands
    class DependencyCommand < Command
      include VersionOption
      include CommandAids

      def initialize
        super('dependency',
          'Show the dependencies of an installed gem',
          {:version=>"> 0"})
        add_version_option('dependency')
        add_option('-r', '--[no-]reverse-dependencies',
          'Include reverse dependencies in the output'
          ) do |value, options|
          options[:reverse_dependencies] = value
        end
        add_option('-p', '--pipe', "Pipe Format (name --version ver)") do |value, options|
          options[:pipe_format] = value
        end
      end

      def defaults_str
        "--version '> 0' --no-reverse"
      end
    
      def usage
        "#{program_name} GEMNAME"
      end

      def arguments
        "GEMNAME   name of gems to show"
      end

      def execute
        specs = {}
        srcindex = SourceIndex.from_installed_gems
        options[:args] << '.' if options[:args].empty?
        options[:args].each do |name|
          speclist = srcindex.search(name, options[:version])
          if speclist.empty?
            say "No match found for #{name} (#{options[:version]})"
          else
            speclist.each do |spec|
              specs[spec.full_name] = spec
            end
          end
        end
        reverse = Hash.new { |h, k| h[k] = [] }
        if options[:reverse_dependencies]
          specs.values.each do |spec|
            reverse[spec.full_name] = find_reverse_dependencies(spec, srcindex)
          end
        end
        if options[:pipe_format]
          specs.values.sort.each do |spec|
            unless spec.dependencies.empty?
              spec.dependencies.each do |dep|
                puts "#{dep.name} --version '#{dep.version_requirements}'"
              end
            end
          end     
        else
          response = ''
          specs.values.sort.each do |spec|
            response << print_dependencies(spec)
            unless reverse[spec.full_name].empty?
              response << "  Used by\n"
              reverse[spec.full_name].each do |sp, dep|
                response << "    #{sp} (#{dep})\n"
              end
            end
            response << "\n"
          end
          say response
        end
      end

      def print_dependencies(spec, level = 0)
        response = ''
        response << '  ' * level + "Gem #{spec.full_name}\n"
        unless spec.dependencies.empty?
  #        response << '  ' * level + "  Requires\n"
          spec.dependencies.each do |dep|
            response << '  ' * level + "  #{dep}\n"
          end
        end
        response
      end

      # Retuns list of [specification, dep] that are satisfied by spec.
      def find_reverse_dependencies(spec, srcindex)
        result = []
        srcindex.each do |name, sp|
          sp.dependencies.each do |dep|
            if spec.name == dep.name &&
                dep.version_requirements.satisfied_by?(spec.version)
              result << [sp.full_name, dep]
            end
          end
        end
        result
      end
    end      
  end
end
