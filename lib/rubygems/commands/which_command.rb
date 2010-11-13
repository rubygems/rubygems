require 'rubygems/command'
require 'rubygems/gem_path_searcher'

class Gem::Commands::WhichCommand < Gem::Command

  EXT = %w[.rb .rbw .so .dll .bundle] # HACK

  def initialize
    super 'which', 'Find the location of a library file you can require',
          :search_gems_first => false, :show_all => false

    add_option '-a', '--[no-]all', 'show all matching files' do |show_all, options|
      options[:show_all] = show_all
    end

    add_option '-g', '--[no-]gems-first',
               'search gems before non-gems' do |gems_first, options|
      options[:search_gems_first] = gems_first
    end
  end

  def arguments # :nodoc:
    "FILE          name of file to find"
  end

  def defaults_str # :nodoc:
    "--no-gems-first --no-all"
  end

  def execute
    searcher = Gem::GemPathSearcher.new

    found = false

    options[:args].each do |arg|
      paths = Gem.find_files(arg, false)

      if options[:search_gems_first]
        paths |= Gem.find_files(arg, true)
      end

      if paths.empty? then
        alert_error "Can't find ruby library file or shared library #{arg}"
      else
        say options[:show_all] ? paths : paths.first
        found = true
      end
    end

    terminate_interaction 1 unless found
  end

  def usage # :nodoc:
    "#{program_name} FILE [FILE ...]"
  end

end

