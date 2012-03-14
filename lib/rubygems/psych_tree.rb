module Gem
  if defined? ::Psych::Visitors
    class NoAliasYAMLTree < Psych::Visitors::YAMLTree
      def visit_String(str)
        return super unless str == '=' # or whatever you want

        quote = Psych::Nodes::Scalar::SINGLE_QUOTED
        @emitter.scalar str, nil, nil, false, true, quote
      end

      # Noop this out so there are no anchors
      def register(target, obj)
      end
    end
  end
end
