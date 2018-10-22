module Loom::Pattern

  ##
  # Pattern::DefinitionContext is the collection of facts, hooks, and
  # parent contexts a pattern is defined along side of. The context
  # includes all contexts of parent modules.
  class DefinitionContext

    NilLetValueError = Class.new Loom::LoomError

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

    # TODO: #define_let_readers is a TERRIBLE name. Rename this method. Also
    # consider moving the instance_exec call to inside RunContext, it's a bit
    # misplaced here.
    #
    # The method is called by Reference#call with the Reference::RunContext
    # instance. The "let" defined local declarations are added as method
    # definitions on each RunContext instance. The @merged_let_map is the map of
    # let definitions, merged from the associated module, up the namespace
    # graph, allowing for inheriting and overriding +let+ declarations.
    def define_let_readers(scope_object, fact_set)
      @merged_let_map.each do |let_key, let_map_entry|
        Loom.log.debug { "evaluating let expression[:#{let_key}]" }
        value = scope_object.instance_exec fact_set, &let_map_entry.block
        value = value.nil? ? let_map_entry.default : value
        Loom.log.debug1(self) { "let[:#{let_key}] => #{value}" }

        if value.nil? || value.equal?(Loom::Facts::EMPTY)
          Loom.log.e "value of let expression[:#{let_key}] is nil"
          raise NilLetValueError, let_key
        end
        scope_object.define_singleton_method(let_key) { value }
      end
    end

    def before_hooks
      Hook.before_hooks merged_hooks
    end

    def after_hooks
      Hook.after_hooks merged_hooks.reverse
    end

    # Helper methods for flattening all parent definition contexts for running a
    # pattern ref.
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

    ##
    # Flattens the list of hooks from all parent modules so that executing the
    # pattern reference executes all expected hooks in the correct order, w/o
    # needing to recurse.
    def merged_hooks
      return hooks if @parent_context.nil?
      merged_contexts.map(&:hooks).flatten
    end

    def merged_contexts
      [@parent_context, self].flatten.compact
    end
  end
end
