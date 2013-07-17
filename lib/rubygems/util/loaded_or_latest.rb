##
# Helper for rubygems_plugins, avoids duplicate call of the plugin
# by checking if the given plugin is already in $LOAD_PATH or
# is the latest available version of the gem.
#
# Usage in lib/rubygems_plugin.rb:
#
#     require 'my_gem'
#     require 'rubygems/util/loaded_or_latest'
#
#     Gem.loaded_or_latest('my_gem') do
#       Gem.post_install do |installer|
#         MyGem.log("Successfully installed #{installer.spec.full_name}")
#       end
#     end
#

module Gem
  def self.loaded_or_latest(name)
    full_file_path = caller.first.split(/:\d/,2).first
    called_path, _, called_version =
      full_file_path.match(
        %r<\A((#{Gem.path*'|'})/gems/#{name}-([^/]+))/.*\Z>
      )[1..3]

    should_be_called =
      $:.detect?{|path| path.start_with?(called_path) } ||
      Gem::Specification.find_by_name(name).version == called_version

  rescue NoMethodError, Gem::LoadError # in case match returns nil or find_by_name fails
    nil
  else
    yield if should_be_called
  end
end
