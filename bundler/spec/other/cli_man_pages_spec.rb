# frozen_string_literal: true

RSpec.describe "bundle commands" do
  let(:command_names) do
    Dir["#{source_root}/lib/bundler/cli/*.rb"].
      grep_v(/common.rb/).
      map {|file_path| File.basename(file_path, ".rb") }
  end

  it "expects all commands to have a man page" do
    command_names.each do |command_name|
      expect(man_page(command_name)).to exist
    end
  end

  it "expects all commands to have all options documented" do
    command_names.each do |command_name|
      command = Bundler::CLI.all_commands[command_name]
      man_page_content = man_page(command_name).read

      command.options.each do |_, option|
        aliases = option.aliases
        formatted_aliases = aliases.sort.map {|name| "`#{name}`" }.join(", ") if aliases

        help = if option.type == :boolean
          "* #{append_aliases("`#{option.switch_name}`", formatted_aliases)}:"
        elsif option.enum
          formatted_aliases = "`#{option.switch_name}`" if aliases.empty? && option.lazy_default
          "* #{prepend_aliases(option.enum.sort.map {|enum| "`#{option.switch_name}=#{enum}`" }.join(", "), formatted_aliases)}:"
        else
          names = [option.switch_name, *aliases]
          value =
            case option.type
            when :array then "<list>"
            when :numeric then "<number>"
            else option.name.upcase
            end

          value = option.type != :numeric && option.lazy_default ? "[=#{value}]" : "=#{value}"

          "* #{names.map {|name| "`#{name}#{value}`" }.join(", ")}:"
        end

        expect(man_page_content).to include(help)
      end
    end
  end

  private

  def append_aliases(text, aliases)
    return text if aliases.empty?

    "#{text}, #{aliases}"
  end

  def prepend_aliases(text, aliases)
    return text if aliases.empty?

    "#{aliases}, #{text}"
  end

  def man_page(command_name)
    source_root.join("lib/bundler/man/bundle-#{command_name}.1.ronn")
  end
end
