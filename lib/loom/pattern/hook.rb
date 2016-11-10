module Loom::Pattern
  class Hook

    class << self
      def around_hooks(hooks)
        hooks.find_all { |h| h.scope == :around }
      end

      def before_hooks(hooks)
        hooks.find_all { |h| h.scope == :before }
      end

      def after_hooks(hooks)
        hooks.find_all { |h| h.scope == :after }
      end
    end

    def initialize(scope, &block)
      unless [:before, :around, :after].include? scope
        raise 'invalid Pattern::DSL hook scope'
      end
      @scope = scope
      @block = block
    end

    attr_reader :scope, :block
  end
end
