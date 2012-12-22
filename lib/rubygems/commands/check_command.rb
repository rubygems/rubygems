require 'rubygems/command'
require 'rubygems/version_option'
require 'rubygems/validator'
require 'pathname'

class Gem::Commands::CheckCommand < Gem::Command

  include Gem::VersionOption

  REPOSITORY_EXTENSION_MAP = {
    'build_info' =>     '.info',
    'cache'      =>     '.gem',
    'doc'        =>     '',
    'gems'       =>     '',
    'specifications' => '.gemspec'
  }

  raise 'Update REPOSITORY_EXTENSION_MAP' unless
    Gem::REPOSITORY_SUBDIRECTORIES == REPOSITORY_EXTENSION_MAP.keys.sort

  def initialize
    super 'check', 'Check a gem repository for added or missing files',
          :alien => true, :doctor => false, :gems => true

    add_option('-a', '--[no-]alien',
               'Report "unmanaged" or rogue files in the',
               'gem repository') do |value, options|
      options[:alien] = value
    end

    add_option('--doctor',
               'Clean up uninstalled gems and broken',
               'specifications') do |value, options|
      options[:doctor] = value
    end

    add_option('--[no-]gems',
               'Check installed gems for problems') do |value, options|
      options[:gems] = value
    end

    add_version_option 'check'
  end

  def check_gems
    say 'Checking gems...'
    say
    gems = get_all_gem_names rescue []

    Gem::Validator.new.alien(gems).sort.each do |key, val|
      unless val.empty? then
        say "#{key} has #{val.size} problems"
        val.each do |error_entry|
          say "  #{error_entry.path}:"
          say "    #{error_entry.problem}"
        end
      else
        say "#{key} is error-free" if Gem.configuration.verbose
      end
      say
    end
  end

  def doctor
    say 'Checking for files from uninstalled gems...'
    say

    paths = Gem.path

    paths.each do |gem_repo|
      say "Checking #{gem_repo}"

      Gem.use_paths gem_repo

      gem_repo = Pathname(gem_repo)

      installed_specs = Gem::Specification.map { |s| s.full_name }

      if installed_specs.empty? then
        say 'This directory does not appear to be a RubyGems repository, ' +
            'skipping'
        next
      end

      REPOSITORY_EXTENSION_MAP.each do |sub_directory, extension|
        directory = gem_repo + sub_directory

        directory.each_child do |child|
          next unless child.exist?

          basename = child.basename(extension).to_s
          next if installed_specs.include? basename
          next if /^rubygems-\d/ =~ basename

          type = child.directory? ? 'directory' : 'file'

          child.rmtree

          say "Removed #{type} #{sub_directory}/#{child.basename}"
        end
      end
    end
  end

  def execute
    check_gems if options[:gems]
    doctor if options[:doctor]
  end

  def arguments # :nodoc:
    'GEMNAME       name of gem to check'
  end

  def defaults_str # :nodoc:
    '--gems --alien'
  end

  def usage # :nodoc:
    "#{program_name} [OPTIONS] [GEMNAME ...]"
  end

end
