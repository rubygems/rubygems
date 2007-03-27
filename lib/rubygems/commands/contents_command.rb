module Gem
  module Commands
    class ContentsCommand < Command
      include CommandAids
      include VersionOption
      def initialize
        super(
          'contents',
          'Display the contents of the installed gems',
          { :list => true, :specdirs => [] })

        add_version_option('contents')

        add_option("-l","--list",'List the files inside a Gem') do |v,o|
          o[:list] = true
        end
      
        add_option('-s','--spec-dir a,b,c', Array, "Search for gems under specific paths") do |v,o|
          o[:specdirs] = v
        end
      
        add_option('-V','--verbose','Be verbose when showing status') do |v,o|
          o[:verbose] = v
        end
      end

      def execute(io=STDOUT)
        if options[:list]
          version = options[:version] || "> 0.0.0"
          gem = get_one_gem_name
        
          s = options[:specdirs].map do |i|
            [i, File.join(i,"specifications")]
          end.flatten
        
          if s.empty?
            s = Gem::SourceIndex.installed_spec_directories
            path_kind = "default gem paths"
            system = true
          else
            path_kind = "specified path"
            system = false
          end

          si = Gem::SourceIndex.from_gems_in(*s)

          gem_spec = si.search(gem, version).last
          unless gem_spec
            io.puts "Unable to find gem '#{gem}' in #{path_kind}"
            if options[:verbose]
              io.puts "\nDirectories searched:"
              s.each do |p|
                io.puts p
              end
            end
            return
          end
          # show the list of files.
          gem_spec.files.each do |f|
            io.puts File.join(gem_spec.full_gem_path, f)
          end
        end
      end
    end
  end
end