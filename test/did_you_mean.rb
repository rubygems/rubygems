# This file exists so we can test that +Gem::UnknownCommandError+ properly
# requires and prepends +DidYouMean+ functionality without needing to turn on
# gems in the test suite. Its function is to mirror the +DidYouMean+ API
# without actually doing anything of consequence.
module DidYouMean
  SPELL_CHECKERS = {} # rubocop:disable Style/MutableConstant

  class SpellChecker

    def initialize(dictionary:) end

    def correct(word)
      word == 'pish' ? %w[push] : []
    end

  end

  module Correctable
    def to_s
      corrections = SPELL_CHECKERS[self.class.name].new(self).corrections
      return super if corrections.empty?

      "#{super}\nDid you mean?  #{corrections.join(', ')}"
    end
  end
end
