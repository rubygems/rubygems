# frozen_string_literal: true

##
# The UriParser handles parsing URIs.
#

class Gem::UriParser

  def initialize(uri_namespace)
    @uri_namespace = uri_namespace
  end

  ##
  # Parses the #uri, raising if it's invalid

  def parse!(uri)
    raise invalid_uri_error unless uri

    # Always escape URI's to deal with potential spaces and such
    # It should also be considered that source_uri may already be
    # a valid URI with escaped characters. e.g. "{DESede}" is encoded
    # as "%7BDESede%7D". If this is escaped again the percentage
    # symbols will be escaped.
    if uri.is_a?(@uri_namespace.const_get(:Generic))
      uri
    else
      begin
        @uri_namespace.public_send(:parse, uri)
      rescue invalid_uri_error
        @uri_namespace.public_send(:parse, @uri_namespace.const_get(:DEFAULT_PARSER).escape(uri))
      end
    end
  end

  ##
  # Parses the #uri, returning the original uri if it's invalid

  def parse(uri)
    parse!(uri)
  rescue invalid_uri_error
    uri
  end

  private

  def invalid_uri_error
    @invalid_uri_error ||= @uri_namespace.const_get(:InvalidURIError)
  end

end
