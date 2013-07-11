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
  def self.loaded_or_latest(name, &block)
    full_file_path = caller.first.split(/:\d/,2).first
    called_path, called_version = full_file_path.match(/^(.*\/#{name}-([^\/]+)\/lib).*$/)[1..2]

    if $:.include?(called_path) || (
      gem_spec = Gem::Specification.find_by_name(name)
      gem_spec && gem_spec.version == called_version
    )
      block.call
    end
  end
end
