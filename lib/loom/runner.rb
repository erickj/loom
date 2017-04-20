module Loom
  class Runner

    include Loom::DSL

    def initialize(loom_config, pattern_slugs=[], runtime_facts={})
      @pattern_slugs = pattern_slugs
      @loom_config = loom_config
      Loom::Facts.add_facts runtime_facts unless runtime_facts.empty?

      @run_failures = []
      @result_reports = []

      # these are initialized in +load+
      @inventory_list = nil
      @active_hosts = nil
      @pattern_refs = nil

      Loom.log.debug1(self) do
        "initialized runner with config => #{loom_config.dump}"
      end

      @caught_sig_int = false
    end

    def run(dry_run)
      install_traps

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
        run_patterns_on_hosts dry_run

        unless @run_failures.empty?
          raise PatternExecutionError, @run_failures
        end
      rescue Loom::Trap::SignalExit => e
        Loom.log.error "exiting on signal  => #{e.signal}"
        # Exit with the signal code or 40 for unknown Signal
        code = Signal.list[e.signal] || 40
        exit code
      rescue PatternExecutionError => e
        num_patterns_failed = @run_failures.size
        Loom.log.error "error executing #{num_patterns_failed} patterns => #{e}"
        Loom.log.debug e.backtrace.join "\n\t"
        exit 100 + num_patterns_failed
      rescue Loom::LoomError => e
        Loom.log.error "loom error => #{e.inspect}"
        exit 98
      rescue => e
        Loom.log.fatal "fatal error => #{e.inspect}"
        Loom.log.fatal e.backtrace.join "\n\t"
        exit 99
      end
    end

    private
    def install_traps
      signal_handler = Loom::Trap::Handler.new do |sig, count|
        case sig
        when Loom::Trap::Sig::INT
          @caught_sig_int = true
          if count == 1
            puts "Caught #{sig}, exiting after current pattern completion"
            puts "Ctrl-C again to exit immediately"
          else
            puts "Caught #{sig}"
            raise Loom::Trap::SignalExit.new sig
          end
        else
          puts "Caught unhandled signal #{sig}"
          raise Loom::Trap::SignalExit.new sig
        end
      end
      Loom::Trap.install(Loom::Trap::Sig::INT, signal_handler)
    end

    # Loads the active hosts from the inventory and patterns from the loom file.
    def load
      @inventory_list =
        Loom::Inventory::InventoryList.active_inventory @loom_config
      @active_hosts = @inventory_list.hosts

      pattern_loader = Loom::Pattern::Loader.load @loom_config
      @pattern_refs = pattern_loader.patterns @pattern_slugs
    end

    def run_patterns_on_hosts(dry_run)
      on_host @active_hosts do |sshkit_backend, host_spec|
        host_session = Loom::HostSession.new(
          host_spec, @loom_config, sshkit_backend)
        host_session.bootstrap

        hostname = host_spec.hostname

        begin
          @pattern_refs.each do |pattern_ref|
            pattern_description = "[#{pattern_ref.slug}@#{hostname}]"

            if @caught_sig_int
              Loom.log.warn "caught SIGINT, skipping #{pattern_description}"
              next
            end

            if host_session.disabled?
              Loom.log.warn "host disabled due to previous failure " +
                "skipping pattern => #{pattern_description}"
              next
            end

            if dry_run
              Loom.log.warn "dry run only => #{pattern_description}"
            else
              Loom.log.info "running pattern => #{pattern_description}"
              host_session.execute_pattern pattern_ref
            end
          end
        rescue IOError => e
          # TODO: Try to patch SSHKit for a more specific error for unexpected SSH
          # disconnections
          host_session.handle_host_failure(
            "unexpected SSH disconnect => #{hostname}")
          Loom.log.error e
        rescue Errno::ECONNREFUSED => e
          host_session.handle_host_failure(
            "unable to connect to host => #{hostname}")
          Loom.log.error e
        end
      end
    end
  end
end
