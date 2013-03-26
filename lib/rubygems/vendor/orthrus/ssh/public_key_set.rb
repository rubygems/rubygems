require 'rubygems/vendor/orthrus/ssh'

module Gem::Orthrus::SSH
  class PublicKeySet
    def self.load_file(path)
      keys = {}

      File.readlines(path).each do |x|
        type, dig, comment = x.split(" ", 3)

        keys[dig] = Orthrus::SSH.parse_public x
      end

      new keys
    end

    def initialize(keys)
      @keys = keys
    end

    def find(dig)
      @keys[dig]
    end

    def num_keys
      @keys.size
    end
  end
end

