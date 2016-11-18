module Loom::Pattern
  class Reference

    attr_reader :slug, :source_file, :desc

    def initialize(slug, unbound_method, source_file, definition_ctx, description)
      @slug = slug
      @unbound_method = unbound_method
      @source_file = source_file
      @definition_ctx = definition_ctx
      @desc = description
    end

    def call(shell_api, host_fact_set)
      run_context = RunContext.new @unbound_method, @definition_ctx

      fact_set = @definition_ctx.fact_set host_fact_set
      @definition_ctx.define_let_readers run_context, fact_set

      begin
        run_context.run shell_api, fact_set
      rescue
        Loom.log.error "error executing pattern => #{slug}\n\t" + $!.message
        raise
      end
    end

    private

    ##
    # A small class to bind the unbound_method to and provide context
    # in the case of errors.
    class RunContext
      def initialize(unbound_method, definition_ctx)
        @bound_method = unbound_method.bind self
        @definition_ctx = definition_ctx
      end

      def run(shell_api, fact_set)
        before_hooks = @definition_ctx.before_hooks
        after_hooks = @definition_ctx.after_hooks

        begin
          Loom.log.debug1(self) { "before hooks => #{before_hooks}"}
          before_hooks.each do |hook|
            Loom.log.debug2(self) { "executing before hook => #{hook}"}
            self.instance_exec shell_api, fact_set, &hook.block
          end

          # This is the entry point into calling patterns.
          apply_pattern shell_api, fact_set
        ensure
          Loom.log.debug1(self) { "after hooks => #{after_hooks}" }
          after_hooks.each do |hook|
            Loom.log.debug2(self) { "executing after hook => #{hook}"}
            self.instance_exec shell_api, fact_set, &hook.block
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
