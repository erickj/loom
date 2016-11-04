module Loom::Pattern

  module Container
    # DO NOT ADD METHODS TO THIS MODULE!!!

    class << self
      def included(pattern_mod)
        Loom.log.debug2(self) { "pattern module loaded => #{pattern_mod}" }
        pattern_mod.extend ClassMethods
      end
    end

    module ClassMethods
      def pattern(name, &block)
        define_method name, &block
      end
    end
    # DO NOT ADD METHODS TO THIS MODULE!!!
  end
end

require_relative "pattern/all"
