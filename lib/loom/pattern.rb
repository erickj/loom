module Loom::Pattern

  module Container
    # DO NOT ADD METHODS TO THIS MODULE!!!

    class << self
      def included(pattern_mod)
        Loom.log.debug2(self) { "pattern module loaded => #{pattern_mod}" }
      end
    end

    # DO NOT ADD METHODS TO THIS MODULE!!!
  end
end

require_relative "pattern/all"
