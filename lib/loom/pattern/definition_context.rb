module Loom::Pattern

  ##
  # Pattern::DefinitionContext is the collection of facts, hooks, and
  # parent contexts a pattern is defined along side of. The context
  # includes all contexts of parent modules.
  class DefinitionContext

    def initialize(pattern_module, parent_context=nil)
      @fact_map = pattern_module.facts.dup
      @let_map = pattern_module.let_map.dup

      @hooks = pattern_module.hooks.dup
      @parent_context = parent_context

      @merged_fact_map = merged_fact_map
      @merged_let_map = merged_let_map
    end

    attr_reader :let_map, :fact_map, :hooks

    ##
    # Merges the facts defined by the pattern context with the host
    # fact_set
    def fact_set(host_fact_set)
      host_fact_set.merge merged_fact_map
    end

    def define_let_readers(scope_object, fact_set)
      @merged_let_map.each do |let_key, block|
        raise "no let block" unless block
        value = scope_object.instance_exec fact_set, &block
        scope_object.define_singleton_method(let_key) { value }
      end
    end

    def before_hooks
      Hook.before_hooks merged_hooks
    end

    def after_hooks
      Hook.after_hooks merged_hooks.reverse
    end

    private
    def merged_fact_map
      merged_contexts.map(&:fact_map).reduce({}) do |merged_map, next_map|
        merged_map.merge! next_map
      end
    end

    def merged_let_map
      merged_contexts.map(&:let_map).reduce({}) do |merged_map, next_map|
        merged_map.merge! next_map
      end
    end

    def merged_hooks
      return hooks if @parent_context.nil?
      merged_contexts.map(&:hooks).flatten
    end

    def merged_contexts
      [@parent_context, self].flatten.compact
    end
  end
end
