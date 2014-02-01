require 'rubygems/test_case'
require 'rubygems/commands/open_command'

class TestGemCommandsOpenCommand < Gem::TestCase

    def setup
        super

        @cmd = Gem::Commands::OpenCommand.new
    end

    def gem name
        spec = quick_gem name do |gem|
            gem.files = %W[lib/#{name}.rb Rakefile]
        end
        write_file File.join(*%W[gems #{spec.full_name} lib #{name}.rb])
        write_file File.join(*%W[gems #{spec.full_name} Rakefile])
    end

    def test_execute
        @cmd.options[:editor] = 'notepad'
        @cmd.options[:args] = %w[foo]

        gem 'foo'

        use_ui @ui do
            @cmd.execute
        end

        assert_equal "", @ui.error
    end


end
