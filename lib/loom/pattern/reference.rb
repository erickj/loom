module Loom::Pattern
  class Reference

    attr_reader :slug, :source_file

    def initialize(slug, unbound_method, original_module_name, source_file, hooks)
      @slug = slug
      @unbound_method = unbound_method
      @original_module_name = original_module_name
      @source_file = source_file
      @hooks = hooks
    end

    def call(shell_api, fact_set)
      run_context = RunContext.new @unbound_method, @hooks.dup

      begin
        run_context.run shell_api, fact_set
      rescue
        Loom.log.error "error executing pattern => #{original_method_name}\n\t" + $!.message
        raise
      end
    end

    private
    def original_method_name
      "%s+%s+" % [@original_module_name, @slug.split(":").last]
    end

    ##
    # A small class to bind the unbound_method to and provide context
    # in the case of errors.
    class RunContext
      def initialize(unbound_method, hooks)
        @bound_method = unbound_method.bind self
        @hooks = hooks
      end

      def run(*args)
        before_hooks = Hook.before_hooks @hooks
        after_hooks = Hook.after_hooks @hooks

        begin
          before_hooks.each do |hook|
            Loom.log.debug4(self) { "executing before hook => #{hook}"}
            self.instance_exec *args, &hook.block
          end

          apply_pattern *args
        ensure
          Loom.log.debug3(self) { "after hooks => #{after_hooks}" }
          after_hooks.each do |hook|
            Loom.log.debug4(self) { "executing after hook => #{hook}"}
            self.instance_exec *args, &hook.block
          end
        end
      end

      private
      def apply_pattern(*args)
        @bound_method.call *args
      end
    end

  end
end
