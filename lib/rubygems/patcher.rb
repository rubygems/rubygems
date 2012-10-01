require "rbconfig"
require "tmpdir"
require "rubygems/package"

class Gem::Patcher
  include Gem::UserInteraction

  class PatchCommandMissing < StandardError; end

  def initialize(gemfile, output_dir)
    @gemfile    = gemfile
    @output_dir = output_dir

    # @target_dir is a temporary directory where the gem files live
    tmpdir      = Dir.mktmpdir
    basename    = File.basename(gemfile, '.gem')
    @target_dir = File.join(tmpdir, basename)
  end

  ##
  # Patch the gem, move the new patched gem to the working directory and return the path

  def patch_with(patches, strip_number)
    check_patch_command_is_installed
    extract_gem

    # Apply all patches
    patches.each do |patch|
      info 'Applying patch ' + patch
      apply_patch(patch, strip_number)
    end

    build_patched_gem

    # Move the newly generated gem to the working directory
    gem_file = IO.read(File.join @target_dir, @package.spec.file_name)

    File.open(File.join(@output_dir, @package.spec.file_name), 'w') do |f|
      f.write gem_file
    end

    # Return the path to the patched gem
    File.join @output_dir, "#{@package.spec.file_name}"
  end

  def apply_patch(patch, strip_number)
    patch_path = File.expand_path(patch)
    info 'Path to the patch to apply: ' + patch_path

    # Apply the patch by calling 'patch -pNUMBER < patch'
    Dir.chdir @target_dir do
      if system("patch --verbose -p#{strip_number} < #{patch_path}")
        info 'Succesfully patched by ' + patch
      else
        info 'Error: Unable to patch with ' + patch
      end
    end
  end

  private

  def extract_gem
    @package = Gem::Package.new @gemfile

    # Unpack
    info "Unpacking gem '#{@gemfile}' in " + @target_dir
    @package.extract_files @target_dir
  end

  def build_patched_gem
    patched_package = Gem::Package.new @package.spec.file_name
    patched_package.spec = @package.spec.clone
    patched_package.spec.files = files_in_gem

    # Change dir and build the patched gem
    Dir.chdir @target_dir do
      patched_package.build false
    end
  end

  def info(msg)
    say msg if Gem.configuration.verbose
  end

  def files_in_gem
    files = []

    Dir.foreach(@target_dir) do |file|
      if File.directory? File.join @target_dir, file
        files += files_in_dir(file) unless /\./.match(file)
      else
        files << file
      end
    end

    delete_original_files(files)
  end

  def files_in_dir(dir)
    files = []

    Dir.foreach(File.join @target_dir, dir) do |file|
      if File.directory? File.join @target_dir, dir, file
        files += files_in_dir(File.join dir, file) unless /\./.match(file)
      else
        files << File.join(dir, file)
      end
    end

    files
  end

  def delete_original_files(files)
    files.each do |file|
      files.delete file if /\.orig/.match(file)
    end
  end

  def check_patch_command_is_installed
    unless system("patch --version")
      raise PatchCommandMissing, 'Calling `patch` command failed. Do you have it installed?'
    end
  end
end