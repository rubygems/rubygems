module Gem
  module Commands
    class HelpCommand < Command
      include CommandAids

      def initialize
        super('help', "Provide help on the 'gem' command")
      end

      def usage
        "#{program_name} ARGUMENT"
      end

      def arguments
        args = <<-EOF
          commands      List all 'gem' commands
          examples      Show examples of 'gem' usage
          <command>     Show specific help for <command>
        EOF
        return args.gsub(/^\s+/, '')
      end

      def execute
        arg = options[:args][0]
        if begins?("commands", arg)
          out = []
          out << "GEM commands are:"
          out << nil

          margin_width = 4
          desc_width = command_manager.command_names.collect {|n| n.size}.max + 4
          summary_width = 80 - margin_width - desc_width
          wrap_indent = ' ' * (margin_width + desc_width)
          format = "#{' ' * margin_width}%-#{desc_width}s%s"

          command_manager.command_names.each do |cmd_name|
            summary = command_manager[cmd_name].summary
            summary = wrap(summary, summary_width).split "\n"
            out << sprintf(format, cmd_name, summary.shift)
            until summary.empty? do
              out << "#{wrap_indent}#{summary.shift}"
            end
          end

          out << nil
          out << "For help on a particular command, use 'gem help COMMAND'."
          out << nil
          out << "Commands may be abbreviated, so long as they are unambiguous."
          out << "e.g. 'gem i rake' is short for 'gem install rake'."

          say out.join("\n")

        elsif begins?("options", arg)
          say Gem::HELP
        elsif begins?("examples", arg)
          say Gem::EXAMPLES
        elsif options[:help]
          command = command_manager[options[:help]]
          if command
            # help with provided command
            command.invoke("--help")
          else
            alert_error "Unknown command #{options[:help]}.  Try 'gem help commands'"
          end
        elsif arg
          possibilities = command_manager.find_command_possibilities(arg.downcase)
          if possibilities.size == 1
            command = command_manager[possibilities.first]
            command.invoke("--help")
          elsif possibilities.size > 1
            alert_warning "Ambiguous command #{arg} (#{possibilities.join(', ')})"
          else
            alert_warning "Unknown command #{arg}. Try gem help commands"
          end
        else
          say Gem::HELP
        end
      end
    end
    
  end
end