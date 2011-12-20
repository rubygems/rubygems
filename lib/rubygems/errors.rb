class Gem::ErrorReason; end # TODO: remove, unnecessary superclass

# TODO move to lib/rubygems/platform_mismatch.rb
# TODO write tests
#--
# Generated when a gem is found that isn't usable on the current platform.
#
class Gem::PlatformMismatch < Gem::ErrorReason

  attr_reader :name
  attr_reader :version
  attr_reader :platforms

  def initialize(name, version)
    @name = name
    @version = version
    @platforms = []
  end

  def add_platform(platform)
    @platforms << platform
  end

  #--
  # Replace only "platforms", remove duplicate strings
  def wordy
    prefix = "Found #{@name} (#{@version})"

    if @platforms.size == 1
      "#{prefix}, but was for platform #{@platforms[0]}"
    else
      "#{prefix}, but was for platforms #{@platforms.join(' ,')}"
    end
  end

end
