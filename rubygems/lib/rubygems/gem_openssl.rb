
# Some system might not have OpenSSL installed, therefore the core
# library file openssl might not be available.  We localize testing
# for the presence of OpenSSL in this file.

module Gem
  class << self
    # Is SSL (used by the signing commands) available on this
    # platform?
    def ssl_available?
      require 'rubygems/gem_openssl'
      @ssl_available
    end
    
    # Set the value of the ssl_avilable flag.
    attr_writer :ssl_available
    
    # Ensure that SSL is available.  Throw an exception if it is not.
    def ensure_ssl_available
      unless ssl_available?
	fail Gem::Exception, "SSL is not installed on this system"
      end
    end
  end
end

begin
  require 'openssl'
  Gem.ssl_available = true
rescue LoadError
  Gem.ssl_available = false
rescue
  Gem.ssl_available = false
end
