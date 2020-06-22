# frozen_string_literal: true

require "rake"
require "rake/tasklib"

require_relative "automatiek/gem"

module Automatiek
  class RakeTask < Rake::TaskLib
    def initialize(*args, &task_block)
      @gem = Gem.new(*args, &task_block)

      namespace :vendor do
        desc "Vendors #{@gem.gem_name}" unless ::Rake.application.last_description
        task(@gem.gem_name, [:version] => []) do |_, task_args|
          @gem.vendor!(task_args[:version])
        end
      end
    end
  end
end
