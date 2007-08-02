require 'rubygems/command'
require 'rubygems/indexer'

class Gem::Commands::GenerateIndexCommand < Gem::Command

  def initialize
    super 'generate_index',
          'Generates the index files for a gem server directory',
          :directory => '.'

    add_option '-d', '--directory=DIRNAME',
               'repository base dir containing gems subdir' do |dir, options|
      options[:directory] = File.expand_path dir
    end
  end

  def execute
    if not File.exist?(options[:directory]) or
       not File.directory?(options[:directory]) then
      alert_error "unknown directory name #{directory}."
      terminate_interaction 1
    else
      indexer = Gem::Indexer::Indexer.new options[:directory]
      indexer.generate_index
    end
  end

end

