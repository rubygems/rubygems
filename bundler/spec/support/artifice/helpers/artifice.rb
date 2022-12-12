# frozen_string_literal: true

# This module was initially borrowed from https://github.com/wycats/artifice
module Artifice
  NET_HTTP = ::Net::HTTP

  # Activate Artifice with a particular Rack endpoint.
  #
  # Calling this method will replace the Net::HTTP system
  # with a replacement that routes all requests to the
  # Rack endpoint.
  #
  # @param [#call] endpoint A valid Rack endpoint
  # @yield An optional block that uses Net::HTTP
  #   In this case, Artifice will be used only for
  #   the duration of the block
  def self.activate_with(endpoint)
    require_relative "rack_request"

    Net::HTTP.endpoint = endpoint
    replace_net_http(Artifice::Net::HTTP)

    if block_given?
      begin
        yield
      ensure
        deactivate
      end
    end
  end

  # Deactivate the Artifice replacement.
  def self.deactivate
    replace_net_http(Net_HTTP)
  end

  def self.replace_net_http(value)
    ::Net.class_eval do
      remove_const(:HTTP)
      const_set(:HTTP, value)
    end
  end
end
