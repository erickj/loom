module Loom
  class Runner

    UnknownPatternError = Class.new Loom::LoomError

    PatternExecutionError = Class.new Loom::LoomError
    FailFastExecutionError = Class.new PatternExecutionError

    include Loom::DSL

    def initialize(loom_config, pattern_slugs=[])
      @pattern_slugs = pattern_slugs
      @loom_config = loom_config

      @pattern_loader = Loom::Pattern::Loader.configure @loom_config
      @inventory_list = Loom::Inventory::InventoryList.active_inventory @loom_config
      @fact_providers = Loom::Facts.fact_providers @loom_config

      @pattern_execution_failures = []
      @result_reports = []

      Loom.log.debug1(self) { "initialized runner with config => #{loom_config.dump}" }
    end

    def run(dry_run)
      begin
        if pattern_refs.empty?
          Loom.log.warn "no patterns given, there's no work to do"
          return
        end
        if active_hosts.empty?
          Loom.log.warn "no hosts in the active inventory"
          return
        end

        pattern_slugs = pattern_refs.map &:slug
        hostnames = active_hosts.map &:hostname
        Loom.log.info do
          "executing patterns #{pattern_slugs} across hosts #{hostnames}"
        end

        run_internal pattern_refs, active_hosts, dry_run

      rescue PatternExecutionError => e
        Loom.log.error "error executing patterns => #{e}"
        Loom.log.debug e.backtrace.join "\n"
        exit 1
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
    def pattern_refs
      @pattern_slugs.map do |slug|
        ref = @pattern_loader[slug]
        raise UnknownPatternError, slug unless ref
        ref
      end
    end

    def active_hosts
      @inventory_list.hosts
    end

    def run_internal(pattern_refs, active_hosts, dry_run)
      # TODO: fix the bindings in the block below so we don't need
      # this alias
      inventory_list = @inventory_list

      on_host active_hosts do |sshkit_backend, host_spec|
        pattern_refs.each do |pattern_ref|
          slug = pattern_ref.slug
          hostname = host_spec.hostname

          pattern_description = "[#{hostname}:#{slug}]"
          if inventory_list.disabled? hostname
            Loom.log.warn "host disabled due to previous failure, " +
                          "skipping: #{pattern_description}"
            return
          end

          Loom.log.info "running pattern => #{pattern_description}"
          # Each pattern execution needs its own shell and mod loader to
          # make sure context is reported correctly
          shell = Loom::Shell.new sshkit_backend, dry_run
          fact_set = Loom::Facts.fact_set host_spec, @fact_providers

          execute_pattern pattern_ref, shell, fact_set
        end
      end

      unless @pattern_execution_failures.empty?
        raise PatternExecutionError, @pattern_execution_failures
      end
    end

    def execute_pattern(pattern_ref, shell, fact_set)
      shell_session = shell.session
      result_reporter = Loom::Pattern::ResultReporter.new(
        @loom_config, pattern_ref.slug, fact_set.hostname, shell_session)
      pattern_ref.call(shell.shell_api, fact_set)
      result_reporter.write_report

      unless shell_session.success?
        @pattern_execution_failures << result_reporter.failure_summary

        failure_strategy = @loom_config.run_failure_stratgy
        case failure_strategy
        when :exclude_host
          Loom.log.warn "disabling host per :run_failure_strategy => #{host.hostname}"
          @inventory_list.disable host.hostname
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
