require 'English'
require 'rubygems/command'
require 'rubygems/version_option'
require 'rubygems/util'

class Gem::Commands::OpenCommand < Gem::Command

    include Gem::VersionOption

    def initialize
        super 'open', 'Open gem sources in editor'

        add_option('-e', '--editor EDITOR', String,
                   "Opens gem sources in EDITOR") do |editor, options|
            options[:editor] = editor ||
                                ENV['GEM_EDITOR'] ||
                                ENV['VISUAL'] ||
                                ENV['EDITOR'] ||
                                'vi'
        end
    end

    def arguments # :nodoc:
        "GEMNAME     name of gem to open in editor"
    end

    def defaults_str # :nodoc:
        "-e $EDITOR"
    end

    def description # :nodoc:
        <<-EOF
        The open command opens gem in editor and changes current path
        to gem's source directory. Editor can be specified, otherwise
        $EDITOR would be invoked.
        EOF
    end

    def usage # :nodoc:
        "#{program_name} GEMNAME [-e EDITOR]"
    end

    def execute
        @version = options[:version] || Gem::Requirement.default
        @editor  = options[:editor]

        found = open_gem(get_one_gem_name)

        terminate_interaction 1 unless found
    end

    def open_gem name
        spec = spec_for name
        return false unless spec

        open_editor(spec.full_gem_path)
    end

    def open_editor path
        Dir.chdir(path) do
            pid = spawn(@editor, path)
            Process.detach(pid)
        end
        #unless Gem::Util.silent_system(@editor, path)
        #    say "Unable to open #{@editor}"
        #    terminate_interaction 1
        #end
    end

    def spec_for name
        spec = Gem::Specification.find_all_by_name(name, @version).last

        return spec if spec

        say "Unable to find gem '#{name}'"
    end
end
