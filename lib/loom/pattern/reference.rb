module Loom::Pattern
  # See Loom::Pattern::Pattern for the difference between refs and patterns.
  class Reference

    attr_reader :slug, :source_file, :desc, :pattern

    def initialize(slug, pattern, source_file, definition_ctx)
      @slug = slug
      @source_file = source_file
      @definition_ctx = definition_ctx
      @desc = pattern.description
      @pattern = pattern
    end

    # Used by Loom::Pattern::Loader to expand weaves. A Pattern::Reference it
    # just expands to itself.
    def expand_slugs
      @slug
    end

    def call(shell_api, host_fact_set)
      run_context = RunContext.new @pattern, @definition_ctx

      fact_set = @definition_ctx.fact_set host_fact_set
      Loom.log.debug5(self) {
        "fact set for pattern execution => #{fact_set.facts}" }

      # TODO: wrap up this fact_set in a delegator/facade/proxy to eliminate the
      # .loom file from directly accessing it. Add logging and deprecation
      # warnings there.... like FactSet+hostname+ currently.
      @definition_ctx.define_let_readers run_context, fact_set

      begin
        run_context.run shell_api, fact_set
      rescue => e
        error_msg = "error executing '#{slug}' in #{source_file} =>\n\t#{e}\n%s"
        Loom.log.error(error_msg % e.backtrace.join("\n\t"))
        raise
      end
    end

    private

    ##
    # A small class to bind the unbound_method to and provide context
    # in the case of errors.
    class RunContext
      def initialize(pattern, definition_ctx)
        @pattern = pattern
        @definition_ctx = definition_ctx
      end

      def run(shell_api, fact_set)
        before_hooks = @definition_ctx.before_hooks
        after_hooks = @definition_ctx.after_hooks

        begin
          Loom.log.debug1(self) { "before hooks => #{before_hooks}"}
          before_hooks.each do |hook|
            Loom.log.debug2(self) { "executing before hook => #{hook}"}
            instance_exec shell_api, fact_set, &hook.block
          end

          # This is the entry point into calling patterns.
          apply_pattern shell_api, fact_set
        ensure
          Loom.log.debug1(self) { "after hooks => #{after_hooks}" }
          after_hooks.each do |hook|
            Loom.log.debug2(self) { "executing after hook => #{hook}"}
            instance_exec shell_api, fact_set, &hook.block
          end
        end
      end

      private

      def apply_pattern(*args)
        instance_exec(*args, &@pattern.pattern_block)
      end
    end

  end
end
