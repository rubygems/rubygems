require "rubygems/command"
require "rubygems/patcher"

class Gem::Commands::PatchCommand < Gem::Command
  def initialize
    super "patch", "Patches the gem with the given patches and generates patched gem.",
      :output => Dir.pwd, :strip => 0

    # Same as 'patch -pNUMBER' on Linux machines
    add_option('-pNUMBER', '--strip=NUMBER', 'Set the file name strip count to NUMBER.') do |number, options|
      options[:strip] = number
    end
  end

  def arguments # :nodoc:
    args = <<-EOF
             GEMFILE           path to the gem file to patch
             PATCH [PATCH ...] list of patches to apply
           EOF
    return args.gsub(/^\s+/, '')
  end

  def description # :nodoc:
    <<-EOF
      The patch command helps to patch gems without manually opening and rebuilding them.
      It opens a given .gem file, extracts it, patches it with system `patch` command,
      clones its spec, updates the file list and builds the patched gem.
    EOF
  end

  def usage # :nodoc:
    "#{program_name} GEMFILE PATCH [PATCH ...]"
  end

  def execute
    gemfile = options[:args].shift
    patches = options[:args]
    
    # No gem
    unless gemfile
      raise Gem::CommandLineError,
        "Please specify a gem file on the command line (e.g. gem patch foo-0.1.0.gem PATCH [PATCH ...])"
    end

    # No patches
    if patches.empty?
      raise Gem::CommandLineError,
        "Please specify patches to apply (e.g. gem patch foo-0.1.0.gem foo.patch bar.patch ...)"
    end

    patcher = Gem::Patcher.new(gemfile, options[:output])
    patcher.patch_with(patches, options[:strip]) 
  end
end
