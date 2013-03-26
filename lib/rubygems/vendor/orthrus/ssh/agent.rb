require 'rubygems/vendor/orthrus/ssh'
require 'rubygems/vendor/orthrus/ssh/buffer'

require 'socket'

# Adapted from agent.rb in net-ssh

module Gem::Orthrus::SSH
  # A trivial exception class for representing agent-specific errors.
  class AgentError < StandardError; end

  # An exception for indicating that the SSH agent is not available.
  class AgentNotAvailable < AgentError; end

  # This class implements a simple client for the ssh-agent protocol. It
  # does not implement any specific protocol, but instead copies the
  # behavior of the ssh-agent functions in the OpenSSH library (3.8).
  #
  # This means that although it behaves like a SSH1 client, it also has
  # some SSH2 functionality (like signing data).
  class Agent
    SSH2_AGENT_REQUEST_VERSION    = 1
    SSH2_AGENT_REQUEST_IDENTITIES = 11
    SSH2_AGENT_IDENTITIES_ANSWER  = 12
    SSH2_AGENT_SIGN_REQUEST       = 13
    SSH2_AGENT_SIGN_RESPONSE      = 14
    SSH2_AGENT_FAILURE            = 30
    SSH2_AGENT_VERSION_RESPONSE   = 103

    SSH_COM_AGENT2_FAILURE        = 102

    SSH_AGENT_REQUEST_RSA_IDENTITIES = 1
    SSH_AGENT_RSA_IDENTITIES_ANSWER1 = 2
    SSH_AGENT_RSA_IDENTITIES_ANSWER2 = 5
    SSH_AGENT_FAILURE                = 5

    # The underlying socket being used to communicate with the SSH agent.
    attr_reader :socket

    # Instantiates a new agent object, connects to a running SSH agent,
    # negotiates the agent protocol version, and returns the agent object.
    def self.connect
      agent = new
      agent.connect!
      agent.negotiate!
      agent
    end

    def self.available?
      ENV.key?("SSH_AUTH_SOCK") && File.exists?(ENV['SSH_AUTH_SOCK'])
    end

    # Creates a new Agent object.
    def initialize
      @socket = nil
    end

    # Connect to the agent process using the socket factory and socket name
    # given by the attribute writers. If the agent on the other end of the
    # socket reports that it is an SSH2-compatible agent, this will fail
    # (it only supports the ssh-agent distributed by OpenSSH).
    def connect!
      begin
        @socket = UNIXSocket.open(ENV['SSH_AUTH_SOCK'])
      rescue
        raise AgentNotAvailable, $!.message
      end
    end

    ID = "SSH-2.0-Ruby/Orthrus #{RUBY_PLATFORM}"

    # Attempts to negotiate the SSH agent protocol version. Raises an error
    # if the version could not be negotiated successfully.
    def negotiate!
      # determine what type of agent we're communicating with
      type, body = send_and_wait(SSH2_AGENT_REQUEST_VERSION, :string, ID)

      if type == SSH2_AGENT_VERSION_RESPONSE
        raise NotImplementedError, "SSH2 agents are not yet supported"
      elsif type != SSH_AGENT_RSA_IDENTITIES_ANSWER1 && type != SSH_AGENT_RSA_IDENTITIES_ANSWER2
        raise AgentError, "unknown response from agent: #{type}, #{body.to_s.inspect}"
      end
    end

    # Return an array of all identities (public keys) known to the agent.
    # Each key returned is augmented with a +comment+ property which is set
    # to the comment returned by the agent for that key.
    def identities
      type, body = send_and_wait(SSH2_AGENT_REQUEST_IDENTITIES)
      raise AgentError, "could not get identity count" if agent_failed(type)
      raise AgentError, "bad authentication reply: #{type}" if type != SSH2_AGENT_IDENTITIES_ANSWER

      identities = []
      body.read_long.times do
        key = Buffer.new(body.read_string).read_key
        case key
        when OpenSSL::PKey::RSA
          key = RSAPublicKey.new key
        when OpenSSL::PKey::DSA
          key = DSAPublicKey.new key
        else
          raise AgentError, "Unknown key type - #{key.class}"
        end

        key.comment = body.read_string
        identities.push key
      end

      return identities
    end

    # Closes this socket. This agent reference is no longer able to
    # query the agent.
    def close
      @socket.close
    end

    # Using the agent and the given public key, sign the given data. The
    # signature is returned in SSH2 format.
    def sign(key, data, b64armor=false)
      type, reply = send_and_wait(SSH2_AGENT_SIGN_REQUEST,
                                  :string, Buffer.from(:key, key),
                                  :string, data,
                                  :long, 0)

      if agent_failed(type)
        raise AgentError, "agent could not sign data with requested identity"
      elsif type != SSH2_AGENT_SIGN_RESPONSE
        raise AgentError, "bad authentication response #{type}"
      end

      b = Buffer.new reply.read_string
      type = b.read_string
      sign = b.read_string

      sign = Utils.encode64 sign if b64armor

      [type, sign]
    end

    private

    # Send a new packet of the given type, with the associated data.
    def send_packet(type, *args)
      buffer = Buffer.from(*args)
      data = [buffer.length + 1, type.to_i, buffer.to_s].pack("NCA*")
      @socket.send data, 0
    end

    # Read the next packet from the agent. This will return a two-part
    # tuple consisting of the packet type, and the packet's body (which
    # is returned as a Net::SSH::Buffer).
    def read_packet
      buffer = Buffer.new @socket.read(4)
      buffer.append @socket.read(buffer.read_long)
      type = buffer.read_byte
      return type, buffer
    end

    # Send the given packet and return the subsequent reply from the agent.
    # (See #send_packet and #read_packet).
    def send_and_wait(type, *args)
      send_packet(type, *args)
      read_packet
    end

    # Returns +true+ if the parameter indicates a "failure" response from
    # the agent, and +false+ otherwise.
    def agent_failed(type)
      type == SSH_AGENT_FAILURE ||
      type == SSH2_AGENT_FAILURE ||
      type == SSH_COM_AGENT2_FAILURE
    end
  end
end
