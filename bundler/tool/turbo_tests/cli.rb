# frozen_string_literal: true

require_relative "../turbo_tests"

require "optparse"

module TurboTests
  class CLI
    def initialize(argv)
      @argv = argv
    end

    def run
      requires = []
      formatters = [{
        :name => "progress",
        :outputs => [],
      }]
      tags = []
      fail_fast = nil

      OptionParser.new do |opts|
        opts.on("-r", "--require PATH", "Require a file.") do |filename|
          requires << filename
        end

        opts.on("-f", "--format FORMATTER", "Choose a formatter.") do |name|
          formatters << {
            :name => name,
            :outputs => [],
          }
        end

        opts.on("-t", "--tag TAG", "Run examples with the specified tag.") do |tag|
          tags << tag
        end

        opts.on("-o", "--out FILE", "Write output to a file instead of $stdout") do |filename|
          formatters.last[:outputs] << filename
        end

        opts.on("--fail-fast=[N]") do |n|
          n = begin
                Integer(n)
              rescue StandardError
                1
              end
          fail_fast = [1, n].max
        end
      end.parse!(@argv)

      requires.each {|f| require(f) }

      formatters.each do |formatter|
        if formatter[:outputs].empty?
          formatter[:outputs] << "-"
        end
      end

      exit TurboTests::Runner.run(
        :formatters => formatters,
        :tags => tags,
        :files => @argv.empty? ? ["spec"] : @argv,
        :fail_fast => fail_fast
      )
    end
  end
end
