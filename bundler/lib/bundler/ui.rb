# frozen_string_literal: true

module Bundler
  module UI
    autoload :JsonShell, File.expand_path("ui/json_shell", __dir__)
    autoload :RGProxy,   File.expand_path("ui/rg_proxy", __dir__)
    autoload :Shell,     File.expand_path("ui/shell", __dir__)
    autoload :Silent,    File.expand_path("ui/silent", __dir__)
  end
end
