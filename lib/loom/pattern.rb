module Loom::Pattern

  # DO NOT ADD METHODS TO THIS MODULE!!!

  class << self
    def included(pattern_mod)
      Loom.log.debug2(self) { "pattern module loaded => #{pattern_mod}" }
      pattern_mod.extend DSL
      pattern_mod.pattern_mod_init
    end
  end

  # DO NOT ADD METHODS TO THIS MODULE!!!
end

require_relative "pattern/all"
