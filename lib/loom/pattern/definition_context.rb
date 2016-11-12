module Loom::Pattern

  ##
  # Pattern::DefinitionContext is the collection of facts, hooks, and
  # parent contexts a pattern is defined along side of. The context
  # includes all contexts of parent modules.
  class DefinitionContext

    def initialize(mod, parent_context=nil)
      @mod = mod
      @fact_map = mod.facts.dup
      @hooks = mod.hooks.dup
      @parent_context = parent_context
      @merged_fact_map = merged_fact_map
    end

    attr_reader :fact_map, :hooks

    ##
    # Merges the facts defined by the pattern context with the host
    # fact_set
    def fact_set(host_fact_set)
      host_fact_set.merge merged_fact_map
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

    def merged_hooks
      return hooks if @parent_context.nil?
      merged_contexts.map(&:hooks).flatten
    end

    def merged_contexts
      [@parent_context, self].flatten.compact
    end
  end
end
