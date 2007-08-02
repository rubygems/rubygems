require 'rubygems/command'
require 'rubygems/server'

class Gem::Commands::ServerCommand < Gem::Command

  def initialize
    super 'server', 'Documentation and gem repository HTTP server',
          :port => 8808, :gemdir => Gem.dir, :daemon => false

    add_option '-p', '--port=PORT',
               'port to listen on' do |port, options|
      options[:port] = port
    end

    add_option '-d', '--dir=GEMDIR',
               'directory from which to serve gems' do |gemdir, options|
      options[:gemdir] = gemdir
    end

    add_option '--daemon', 'run as a daemon' do |daemon, options|
      options[:daemon] = daemon
    end
  end

  def execute
    Gem::Server.run options
  end

  def usage
    "#{program_name} [options]"
  end

end

