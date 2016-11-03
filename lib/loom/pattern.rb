module Loom::Pattern

  module Container
    # DO NOT ADD METHODS TO THIS MODULE!!!

    class << self
      def included(pattern_mod)
        Loom.log.debug2(self) { "pattern module found => #{pattern_mod}" }
      end

      ##
      # Registers methods as they're added to Pattern::Container
      # modules as patterns
      def method_added(method_name)
        # shell_module = Loom::Pattern::Shell
        # pattern_slug = "#{self.name}:#{shell_module.name}".
        #                  gsub(/^#{prefix}/, "").
        #                  gsub(/^:+/, "").
        #                  downcase

        # Loom::Pattern.loaded_pattern_slugs[pattern_slug] = method
      end
    end

    # DO NOT ADD METHODS TO THIS MODULE!!!
  end
end

require_relative "pattern/all"
