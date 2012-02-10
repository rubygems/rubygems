class Gem::UriFormatter
  attr_reader :uri

  def initialize(uri)
    @uri = uri
  end

  def escape
    return unless uri
    @uri_parser ||= escaper
    @uri_parser.escape uri
  end

  def unescape
    return unless uri
    @uri_parser ||= escaper
    @uri_parser.unescape uri
  end

  ##
  # Normalize the URI by adding "http://" if it is missing.

  def normalize
    (uri =~ /^(https?|ftp|file):/) ? uri : "http://#{uri}"
  end

  private

  def escaper
    URI::Parser.new
  rescue NameError
    URI
  end
end
