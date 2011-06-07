require 'rubygems'
require 'rubygems/user_interaction'

Gem.post_install do |installer|
  ui = Gem::DefaultUserInteraction.ui
  ui.say "Successfully installed #{installer.spec.full_name}"
end

