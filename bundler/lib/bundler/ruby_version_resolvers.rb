module Bundler
  class RubyVersionResolvers
    @resolvers = {
      ruby_version: -> {
        Bundler.read_file(Bundler.root.join(".ruby-version")).strip
      },
      tool_versions: -> {
        contents = Bundler.read_file(Bundler.root.join(".tool-versions"))
        contents[/^ruby\s+(\w+)/, 1]
      }
    }

    class << self
      attr_reader :resolvers
    end
  end
end
