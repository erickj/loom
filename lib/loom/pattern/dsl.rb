module Loom::Pattern
  module DSL

    def pattern_methods
      @pattern_methods || []
    end

    def pattern(name, &block)
      Loom.log.debug3(self) { "defined pattern method => #{name}" }
      @pattern_methods ||= []

      method_name = name.to_sym

      @pattern_methods << method_name
      define_method method_name, &block
    end

    def let(name, &block)
      @let_fields ||= {}
      @let_fields[name.to_sym] = yield
    end

    def let_fields
      @let_fields || {}
    end

    def hooks
      @hooks || []
    end

    def hook(scope, &block)
      @hooks ||= []
      @hooks << Hook.new(scope, &block)
    end

    def around(&block)
      raise 'not implemented'
    end

    def before(&block)
      hook :before, &block
    end

    def after(&block)
      hook :after, &block
    end

  end
end
