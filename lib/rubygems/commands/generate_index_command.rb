require 'rubygems/command'

class Gem::Commands::GenerateIndexCommand < Gem::Command

  def initialize
    super 'generate_yaml_index',
          'Generates the index files for a gem server directory',
          :directory => '.', :quick => true

    add_option '-d', '--directory=DIRNAME',
               'repository base dir containing gems subdir' do |dir, options|
      options[:directory] = File.expand_path dir
    end

    add_option '--[no-]quick', 'generate quick index' do |quick, options|
      options[:quick] = quick
    end
  end

  def execute
    if not File.exist?(options[:directory]) or
       not File.directory?(options[:directory]) then
      alert_error "unknown directory name #{directory}."
      terminate_interaction 1
    else
      require 'rubygems/indexer'

      Gem::Indexer::Indexer.new(options).build_index
    end
  end

end

