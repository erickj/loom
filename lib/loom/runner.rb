module Loom
  class Runner

    PatternExecutionError = Class.new Loom::LoomError
    FailFastExecutionError = Class.new PatternExecutionError

    include Loom::DSL

    def initialize(loom_config, pattern_slugs=[])
      @pattern_slugs = pattern_slugs
      @loom_config = loom_config
      @run_failures = []
      @result_reports = []

      # these are initialized in +load+
      @inventory_list = nil
      @active_hosts = nil
      @pattern_refs = nil

      Loom.log.debug1(self) do
        "initialized runner with config => #{loom_config.dump}"
      end
    end

    def run(dry_run)
      begin
        load

        if @pattern_refs.empty?
          Loom.log.warn "no patterns given, there's no work to do"
          return
        end
        if @active_hosts.empty?
          Loom.log.warn "no hosts in the active inventory"
          return
        end

        hostnames = @active_hosts.map(&:hostname)
        Loom.log.info do
          "executing patterns #{@pattern_slugs} across hosts #{hostnames}"
        end

        run_internal dry_run

        unless @run_failures.empty?
          raise PatternExecutionError, @run_failures
        end
      rescue PatternExecutionError => e
        num_patterns_failed = @run_failures.size
        Loom.log.error "error executing #{num_patterns_failed} patterns => #{e}"
        Loom.log.debug e.backtrace.join "\n"
        exit 100 + num_patterns_failed
      rescue Loom::LoomError => e
        Loom.log.error "loom error => #{e.inspect}"
        exit 2
      rescue => e
        Loom.log.fatal "fatal error => #{e.inspect}"
        Loom.log.fatal e.backtrace.join "\n\t"
        exit 3
      end
    end

    private

    def load
      @inventory_list =
        Loom::Inventory::InventoryList.active_inventory @loom_config
      @active_hosts = @inventory_list.hosts

      pattern_loader = Loom::Pattern::Loader.load @loom_config
      @pattern_refs = pattern_loader.patterns @pattern_slugs
    end

    def run_internal(dry_run)
      # TODO: fix the bindings in the block below so we don't need
      # this alias
      inventory_list = @inventory_list

      on_host @active_hosts do |sshkit_backend, host_spec|
        @pattern_refs.each do |pattern_ref|
          slug = pattern_ref.slug
          hostname = host_spec.hostname

          pattern_description = "[#{hostname}:#{slug}]"
          if inventory_list.disabled? hostname
            Loom.log.warn "host disabled due to previous failure, " +
                          "skipping: #{pattern_description}"
            return
          end

          Loom.log.debug "collecting facts for => #{pattern_description}"
          # Collect facts for each pattern run on each host, this way
          # if one pattern run updates would be facts, the next
          # pattern will see the new fact.
          fact_shell = Loom::Shell.new sshkit_backend, dry_run
          fact_set = Loom::Facts.fact_set host_spec, fact_shell, @loom_config

          Loom.log.info "running pattern => #{pattern_description}"
          # Each pattern execution needs its own shell and mod loader to
          # make sure context is reported correctly
          pattern_shell = Loom::Shell.new sshkit_backend, dry_run
          execute_pattern pattern_ref, pattern_shell, fact_set
        end
      end
    end

    def execute_pattern(pattern_ref, shell, fact_set)
      shell_session = shell.session
      hostname = fact_set.hostname
      result_reporter = Loom::Pattern::ResultReporter.new(
        @loom_config, pattern_ref.slug, hostname, shell_session)

      begin
        pattern_ref.call(shell.shell_api, fact_set)
      rescue Loom::ExecutionError => e
        Loom.log.warn "execution error => #{e}"
        @run_failures << e.message
      end

      result_reporter.write_report

      unless shell_session.success?
        @run_failures << result_reporter.failure_summary

        failure_strategy = @loom_config.run_failure_strategy
        case failure_strategy.to_sym
        when :exclude_host
          Loom.log.warn "disabling host per :run_failure_strategy => #{failure_strategy}"
          @inventory_list.disable hostname
        when :fail_fast
          Loom.log.error "erroring out of failed scenario per :run_failure_strategy"
          raise FailFastExecutionError, result_reporter.failure_summary
        when :cowboy
          Loom.log.warn result_reporter.failure_summary
          Loom.log.warn "continuing on past failed scenario per :run_failure_strategy"
        else
          raise ConfigError, "unknown failure_strategy: #{failure_stratgy}"
        end
      end
      @result_reports << result_reporter
    end
  end
end
