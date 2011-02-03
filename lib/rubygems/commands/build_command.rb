require 'rubygems/command'
require 'rubygems/builder'

class Gem::Commands::BuildCommand < Gem::Command

  def initialize
    super('build', 'Build a gem from a gemspec')
    
    add_option('-C', '--certificate-chain CERT',
               'Sets a certificate to the certificate chain, replacing the chain specified in the gemspec. CERT has to be a comma-separated list of cert files') do |value, options|
      require 'rubygems/security'
      options[:cert_chain] ||= []
      value.split(',').each do |cert_file|
        cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
        options[:cert_chain] << cert
      end
    end

    add_option('-K', '--private-key KEY',
               'Set the private key for signing, replacing the one specified in gemspec') do |value, options|
      require 'rubygems/security'
      key = OpenSSL::PKey::RSA.new(File.read(value))
      options[:signing_key] = key
    end
  end

  def arguments # :nodoc:
    "GEMSPEC_FILE  gemspec file name to build a gem for"
  end

  def usage # :nodoc:
    "#{program_name} GEMSPEC_FILE"
  end

  def execute
    gemspec = get_one_gem_name
    if File.exist?(gemspec)
      specs = load_gemspecs(gemspec)
      specs.each do |spec|
        # Set default cert_chain and signing_key if none are set in gemspec

        # TODO: This may be better placed directly in the gemspec generation routine,
        # but I did not want to break anything.  -- Alexander E. Fischer <aef@raxys.net>, 2010-02-03
        if not Gem.configuration.cert_chain.empty? and spec.cert_chain.empty?
          spec.cert_chain = Gem.configuration.cert_chain
        end

        if not Gem.configuration.signing_key.nil? and spec.signing_key.nil?
          spec.signing_key = Gem.configuration.signing_key
        end

        # Replaces cert_chain and signing_key if given on command line
        spec.signing_key = options[:signing_key] if options[:signing_key]
        spec.cert_chain  = options[:cert_chain]  if options[:cert_chain]
        Gem::Builder.new(spec).build
      end
    else
      alert_error "Gemspec file not found: #{gemspec}"
    end
  end

  def load_gemspecs(filename)
    if yaml?(filename)
      result = []
      open(filename) do |f|
        begin
          while not f.eof? and spec = Gem::Specification.from_yaml(f)
            result << spec
          end
        rescue Gem::EndOfYAMLException
          # OK
        end
      end
    else
      result = [Gem::Specification.load(filename)]
    end
    result
  end

  def yaml?(filename)
    line = open(filename) { |f| line = f.gets }
    result = line =~ %r{!ruby/object:Gem::Specification}
    result
  end
end
