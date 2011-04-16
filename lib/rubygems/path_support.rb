require 'rubygems/fs'

##
#
# Gem::PathSupport facilitates the GEM_HOME and GEM_PATH environment settings
# to the rest of RubyGems.
#
class Gem::PathSupport
  ##
  # The system environment provided. Defaults to ENV.
  attr_reader :env

  ##
  # The default system path for managing Gems.
  attr_reader :home

  ##
  # Array of paths to search for Gems.
  attr_reader :path

  ##
  #
  # Constructor. Takes a single argument which is to be treated like a
  # hashtable, or defaults to ENV, the system environment.
  #
  def initialize(env=ENV)
    @env = env

    # hack for JRuby, which treats ENV as Hash, inappropriately
    # more info: http://jira.codehaus.org/browse/JRUBY-4947
    is_not_system_env = if RUBY_PLATFORM =~ /java/
                          # note that this does not work around dup, clone,
                          # etc. This is intentional as we *should not* be
                          # modifying the system environment at that point.
                          #
                          # Once ENV is dup'd the string constraint no longer
                          # applies, as well.
                          #
                          # -ebh
                          !env.equal?(ENV)
                        else
                          env.kind_of?(Hash)
                        end

    # ENV the machine environment, is type Object, which is why this works.
    if is_not_system_env
      @home = Gem::FS.new(env[:home] || ENV["GEM_HOME"] || Gem.default_dir)
      self.path = env[:path] || ENV["GEM_PATH"]
    else
      @home = Gem::FS.new(env["GEM_HOME"] || Gem.default_dir) 
      self.path = env["GEM_PATH"]
    end
  end

  private

  ##
  # Set the Gem home directory (as reported by Gem.dir).

  def home=(home)
    @home = Gem::FS.new(home)
  end

  ##
  # Set the Gem search path (as reported by Gem.path).

  def path=(gpaths)
    gem_path = []

    gpaths ||= (ENV['GEM_PATH'] || "").empty? ? nil : ENV["GEM_PATH"]

    if gpaths
      if gpaths.kind_of?(Array)
        gem_path = gpaths.dup
      else
        gem_path = gpaths.split(File::PATH_SEPARATOR)
      end

      if File::ALT_SEPARATOR then
        gem_path.map! do |this_path|
          this_path.gsub File::ALT_SEPARATOR, File::SEPARATOR
        end
      end

      gem_path << @home
    else
      gem_path = Gem.default_path + [@home]

      if defined?(Gem::APPLE_GEM_HOME)
        gem_path << Gem::APPLE_GEM_HOME
      end
    end

    @path = gem_path.map { |this_path| Gem::FS.new(this_path) }.uniq
  end
end
