# frozen_string_literal: true

##
# The Uri handles rubygems source URIs.
#

class Gem::Uri
  def initialize(source_uri)
    @parsed_uri = parse(source_uri)
  end

  def redacted
    if token?
      clone.tap(&:redact_user!)
    elsif oauth_basic?
      clone.tap(&:redact_user!)
    elsif password?
      clone.tap(&:redact_password!)
    else
      self
    end
  end

  def to_s
    @parsed_uri.to_s
  end

  def redact_credentials_from(text)
    return text unless password?

    text.sub(password, 'REDACTED')
  end

  def method_missing(method_name, *args, &blk)
    if @parsed_uri.respond_to?(method_name)
      @parsed_uri.send(method_name, *args, &blk)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    @parsed_uri.respond_to?(method_name, include_private) || super
  end

  private

  def parse(uri)
    return uri unless uri.is_a?(String)

    require "uri"

    # Always escape URI's to deal with potential spaces and such
    # It should also be considered that source_uri may already be
    # a valid URI with escaped characters. e.g. "{DESede}" is encoded
    # as "%7BDESede%7D". If this is escaped again the percentage
    # symbols will be escaped.
    begin
      URI.parse(uri)
    rescue URI::InvalidURIError
      URI.parse(URI::DEFAULT_PARSER.escape(uri))
    end
  end

  def redact_user!
    self.user = 'REDACTED'
  end

  def redact_password!
    self.password = 'REDACTED'
  end

  def password?
    !!password
  end

  def oauth_basic?
    password == 'x-oauth-basic'
  end

  def token?
    !user.nil? && password.nil?
  end
end
