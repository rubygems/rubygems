require 'rubygems/command'

class Gem::Commands::WhereisCommand < Gem::Command
  def initialize
    super 'whereis', 'Find the location of a named gem',
          show_all: false

    add_option '-a', '--[no-]all', 'show all versions' do |show_all, options|
      options[:show_all] = show_all
    end
  end

  def usage # :nodoc:
    "#{program_name} GEMNAME [REQUIREMENT ...]"
  end

  def arguments # :nodoc:
    <<-ARGS
GEMNAME       name of gem to find
REQUIREMENT   optional version specifier(s)
    ARGS
  end

  def defaults_str # :nodoc:
    " --no-all"
  end

  def description # :nodoc:
    <<-EOF
The whereis command shows the base directory where a specified gem is
installed.

If -a/--all is given, it shows the base directories of all installed
versions of a gem that matches a given query.
    EOF
  end

  def execute
    name, *requirements = options[:args]

    if !name
      alert_error "Please specify a gem name"
      terminate_interaction 1
    end

    begin
      if options[:show_all]
        specs = Gem::Specification.find_all_by_name(name, *requirements)
      else
        specs = [Gem::Specification.find_by_name(name, *requirements)]
      end
    rescue Gem::LoadError
      if requirements.empty?
        alert_error "Can't find installed gem(s) named #{name}"
      else
        alert_error "Can't find installed gem(s) named #{name} [#{requirements.join(', ')}]"
      end
      terminate_interaction 1
    end

    say specs.map(&:gem_dir)
  end
end
