module Loom::Pattern
  module DSL

    loom_accessor :namespace

    def description(description)
      @next_description = description
    end
    alias_method :desc, :description

    def with_facts(**new_facts, &block)
      @facts ||= {}
      @facts.merge! new_facts
      yield_result = yield @facts if block_given?
      @facts = yield_result if yield_result.is_a? Hash
    end

    def pattern(name, &block)
      Loom.log.debug3(self) { "defined pattern method => #{name}" }
      @pattern_methods ||= []
      @pattern_method_map ||= {}
      @pattern_descriptions ||= {}

      method_name = name.to_sym

      @pattern_methods << method_name
      @pattern_method_map[method_name] = true
      @pattern_descriptions[method_name] = @next_description
      @next_description = nil

      define_method method_name, &block
    end

    def hook(scope, &block)
      @hooks ||= []
      @hooks << Hook.new(scope, &block)
    end

    def before(&block)
      hook :before, &block
    end

    def after(&block)
      hook :after, &block
    end

    def pattern_methods
      @pattern_methods || []
    end

    def pattern_description(name)
      @pattern_descriptions[name]
    end

    def pattern_method(name)
      raise UnknownPatternMethod, name unless @pattern_method_map[name]
      instance_method name
    end

    def hooks
      @hooks || []
    end

    def facts
      @facts || {}
    end
  end
end
