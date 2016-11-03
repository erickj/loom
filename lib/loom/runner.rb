module Loom
  class Runner

    UnknownPatternError = Class.new Loom::LoomError
    FailFastExecutionError = Class.new Loom::LoomError

    include Loom::DSL

    def initialize(loom_config, pattern_slugs=[])
      @pattern_slugs = pattern_slugs
      @loom_config = loom_config
      @inventory_list = nil

      Loom.log.debug1(self) { "initialized runner with config => #{loom_config.dump}" }
    end

    def run(dry_run)
      begin
        run_internal dry_run
      rescue Loom::LoomError => e
        Loom.log.error "loom error => #{e.inspect}"
        exit 1
      rescue => e
        Loom.log.fatal "fatal error => #{e.inspect}"
        Loom.log.fatal e.backtrace.join "\n\t"
        exit 2
      end
    end

    private
    def run_internal(dry_run)
      pattern_loader = Loom::Pattern::Loader.configure @loom_config
      @inventory_list = Loom::Inventory::InventoryList.active_inventory @loom_config

      if @pattern_slugs.empty?
        Loom.log.warn "no patterns given, there's no work to do"
        return
      end

      active_hosts = @inventory_list.hosts

      if active_hosts.empty?
        Loom.log.warn "no hosts in the active inventory"
        return
      end

      pattern_slugs = @pattern_slugs
      inventory_list = @inventory_list

      Loom.log.info "executing: #{active_hosts.map &:hostname} over #{pattern_slugs}"
      on_host active_hosts, self do |shell, mods, host|
        pattern_slugs.each do |pattern_slug|
          pattern_ref = pattern_loader[pattern_slug]
          raise UnknownPatternError, pattern_slug unless pattern_ref

          pattern_description = "#{host.hostname} => #{pattern_slug}"
          if inventory_list.disabled? host.hostname
            Loom.log.warn "host disabled due to previous failure, " +
                          "skipping: #{pattern_description}"
            return
          end
 
          if dry_run
            Loom.log.warn "dry run: #{pattern_description}"
          else
            Loom.log.info pattern_description
            run_pattern pattern_ref, shell, mods, host
          end
        end
      end
    end

    def run_pattern(pattern_ref, shell, mods, host)
      shell_session = shell.session
      result_reporter = Loom::Pattern::ResultReporter.new pattern_ref.slug, host, shell_session
      pattern_ref.call(shell, mods, host)
      result_reporter.write_report

      unless shell_session.success?
        case @loom_config.failure_stratgy
        when :exclude_host
          Loom.log.warn "disabling host per failure_strategy => #{host.hostname}"
          @inventory_list.disable host.hostname
        when :fail_fast
          Loom.log.error "erroring out of failed scenario per failure_strategy"
          raise FailFastExecutionError, result_reporter.failure_summary
        when :cowboy
          Loom.log.warn result_reporter.failure_summary
          Loom.log.warn "continuing on past failed scenario per failure_strategy"
        else
          raise ConfigError, "unknown failure_strategy: #{@loom_config.failure_stratgy}"
        end
      end
    end
  end
end
