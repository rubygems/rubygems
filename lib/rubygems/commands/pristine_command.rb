module Gem
  module Commands
    class PristineCommand < Command
      include VersionOption
      include CommandAids
      def initialize
        super('pristine',
          'Restores gem directories to pristine condition from files located in the gem cache',
          {
            :version => "> 0.0.0"
          })
        add_option('--all',
          'Restore all installed gems to pristine', 'condition'
          ) do |value, options|
          options[:all] = value
        end
        add_version_option('restore to', 'pristine condition')
      end

      def defaults_str
        "--all"
      end

      def usage
        "#{program_name} [args]"
      end

      def arguments
        "GEMNAME          The gem to restore to pristine condition (unless --all)"
      end

      def execute
        say "Restoring gem(s) to pristine condition..."
        if options[:all]
          all_gems = true
          specs = Gem::SourceIndex.from_installed_gems.collect do |name, spec|
            spec
          end
        else
          all_gems = false
          gem_name = get_one_gem_name
          specs = Gem::SourceIndex.from_installed_gems.search(gem_name, options[:version])
        end

        if specs.empty?
          fail "Failed to find gem #{gem_name} #{options[:version]} to restore to pristine condition"
        end
        install_dir = Gem.dir # TODO use installer option
        raise Gem::FilePermissionError.new(install_dir) unless File.writable?(install_dir)

        gems_were_pristine = true

        specs.each do |spec|
          installer = Gem::Installer.new nil, :wrappers => true # HACK ugly TODO use installer option

          gem_file = File.join(install_dir, "cache", "#{spec.full_name}.gem")
          security_policy = nil # TODO use installer option
          format = Gem::Format.from_file_by_path(gem_file, security_policy)
          target_directory = File.join(install_dir, "gems", format.spec.full_name).untaint
          pristine_files = format.file_entries.collect {|data| data[0]["path"]}
          file_map = {}
          format.file_entries.each {|entry, file_data| file_map[entry["path"]] = file_data}
          require 'fileutils'

          Dir.chdir target_directory do
            deployed_files = Dir.glob(File.join("**", "*")) +
                             Dir.glob(File.join("**", ".*"))
            to_redeploy = (pristine_files - deployed_files).collect {|path| path.untaint}
            if to_redeploy.length > 0
              gems_were_pristine = false
              say "Restoring #{to_redeploy.length} file#{to_redeploy.length == 1 ? "" : "s"} to #{spec.full_name}..."
              to_redeploy.each do |path|
                say "  #{path}"
                FileUtils.mkdir_p File.dirname(path)
                File.open(path, "wb") do |out|
                  out.write file_map[path]
                end
              end
            end
          end

          installer.generate_bin spec, install_dir
        end

        say "Rebuilt all bin stubs"

        if gems_were_pristine
          if all_gems
            say "All installed gem files are already in pristine condition"
          else
            say "#{specs[0].full_name} is already in pristine condition"
          end
        else
          if all_gems
            say "All installed gem files restored to pristine condition"
          else
            say "#{specs[0].full_name} restored to pristine condition"
          end
        end
      end
    end    
  end
end