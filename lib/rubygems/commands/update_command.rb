module Gem
  module Commands
    class UpdateCommand < Command
      include InstallUpdateOptions

      def initialize
        super(
          'update',
          'Update the named gem (or all installed gems) in the local repository',
          {
            :generate_rdoc => true, 
            :generate_ri => true, 
            :force => false, 
            :test => false,
            :install_dir => Gem.dir
          })
        add_install_update_options
        add_option('--system',
          'Update the RubyGems system software') do |value, options|
          options[:system] = value
        end
      end
    
      def defaults_str
        "--rdoc --ri --no-force --no-test\n" +
        "--install-dir #{Gem.dir}"
      end

      def arguments
        "GEMNAME(s)   name of gem(s) to update"
      end

      def execute
        if options[:system]
          say "Updating RubyGems..."
          if ! options[:args].empty?
            fail "No gem names are allowed with the --system option"
          end
          options[:args] = ["rubygems-update"]
        else
          say "Updating installed gems..."
        end
        hig = highest_installed_gems = {}
        Gem::SourceIndex.from_installed_gems.each do |name, spec|
          if hig[spec.name].nil? or hig[spec.name].version < spec.version
            hig[spec.name] = spec
          end
        end
        remote_gemspecs = Gem::SourceInfoCache.search(//)
        gems_to_update =  if(options[:args].empty?) then
                            which_to_update(highest_installed_gems, remote_gemspecs)
                          else
                            options[:args]
                          end
        options[:domain] = :remote # install from remote source
        install_command = command_manager['install']
        gems_to_update.uniq.sort.each do |name|
          say "Attempting remote update of #{name}"
          options[:args] = [name]
          install_command.merge_options(options)
          install_command.execute
        end
        if gems_to_update.include?("rubygems-update")
          latest_ruby_gem = remote_gemspecs.select { |s|
            s.name == 'rubygems-update' 
          }.sort_by { |s|
            s.version
          }.last
          say "Updating version of RubyGems to #{latest_ruby_gem.version}"
          do_rubygems_update(latest_ruby_gem.version.to_s)
        end
        if(options[:system]) then
          say "RubyGems system software updated"
        else
          say "Gems: [#{gems_to_update.uniq.sort.collect{|g| g.to_s}.join(', ')}] updated"
        end
      end

      def do_rubygems_update(version_string)
        update_dir = File.join(Gem.dir, "gems", "rubygems-update-#{version_string}")
        Dir.chdir(update_dir) do
          puts "Installing RubyGems #{version_string}"
          system "#{Gem.ruby} setup.rb"
        end
      end

      def which_to_update(highest_installed_gems, remote_gemspecs)
        result = []
        highest_installed_gems.each do |l_name, l_spec|
          highest_remote_gem =
            remote_gemspecs.select  { |spec| spec.name == l_name }.
                            sort_by { |spec| spec.version }.
                            last
          if highest_remote_gem and l_spec.version < highest_remote_gem.version
            result << l_name
          end
        end
        result
      end
    end
  end
end