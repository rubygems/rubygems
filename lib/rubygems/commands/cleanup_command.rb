module Gem
  module Commands
    class CleanupCommand < Command
      def initialize
        super(
          'cleanup',
          'Clean up old versions of installed gems in the local repository',
          {
            :force => false, 
            :test => false, 
            :install_dir => Gem.dir
          })
        add_option('-d', '--dryrun', "") do |value, options|
          options[:dryrun] = true
        end
      end
    
      def defaults_str
        "--no-dryrun"
      end

      def arguments
        "GEMNAME(s)   name of gem(s) to cleanup"
      end

      def execute
        say "Cleaning up installed gems..."
        srcindex = Gem::SourceIndex.from_installed_gems
        primary_gems = {}
        srcindex.each do |name, spec|
          if primary_gems[spec.name].nil? or primary_gems[spec.name].version < spec.version
            primary_gems[spec.name] = spec
          end
        end
        gems_to_cleanup = []
        if ! options[:args].empty?
          options[:args].each do |gem_name|
            specs = Gem.cache.search(/^#{gem_name}$/i)
            specs.each do |spec|
              gems_to_cleanup << spec
            end
          end
        else
          srcindex.each do |name, spec|
              gems_to_cleanup << spec
          end
        end
        gems_to_cleanup = gems_to_cleanup.select { |spec|
          primary_gems[spec.name].version != spec.version
        }
        uninstall_command = command_manager['uninstall']
        deplist = DependencyList.new
        gems_to_cleanup.uniq.each do |spec| deplist.add(spec) end
        deplist.dependency_order.each do |spec|
          if options[:dryrun]
            say "Dry Run Mode: Would uninstall #{spec.full_name}"
          else
            say "Attempting uninstall on #{spec.full_name}"
            options[:args] = [spec.name]
            options[:version] = "= #{spec.version}"
            options[:executables] = true
            uninstall_command.merge_options(options)
            begin
              uninstall_command.execute
            rescue Gem::DependencyRemovalException => ex
              say "Unable to uninstall #{spec.full_name} ... continuing with remaining gems"
            end
          end
        end
        say "Clean Up Complete"
      end
    end
      
  end
end
