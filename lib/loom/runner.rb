module Loom
  # TODO: Make Loom::Runner a module and move this to
  # Loom::Runner::Core. Loom::RunnerModule is set up as a temporary namespace
  # until that happens.
  class Runner

    PatternExecutionError = Class.new Loom::LoomError
    FailFastExecutionError = Class.new PatternExecutionError

    include Loom::RunnerModule::SSHKitConnector

    def initialize(loom_config, pattern_slugs=[], other_facts={})
      @pattern_slugs = pattern_slugs
      @loom_config = loom_config
      @other_facts = other_facts

      @run_failures = []
      @result_reports = []

      # these are initialized in +load+
      @inventory_list = nil
      @active_hosts = nil
      @pattern_refs = nil
      @mod_loader = nil

      Loom.log.debug1(self) do
        "initialized runner with config => #{loom_config.dump}"
      end

      @caught_sig_int = false
    end

    def run(dry_run)
      install_signal_traps

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
      rescue Loom::Trap::SignalExit => e
        Loom.log.error "exiting on signal  => #{e.signal}"
        # Exit with the signal code or 40 for unknown Signal
        code = Signal.list[e.signal] || 40
        exit code
      rescue PatternExecutionError => e
        num_patterns_failed = @run_failures.size
        Loom.log.error "error executing #{num_patterns_failed} patterns => #{e}, run with -d for more"
        Loom.log.debug e.backtrace.join "\n\t"
        # TODO: I think the max return code is 255. Cap this if so.
        exit 100 + num_patterns_failed
      rescue SSHKit::Runner::ExecuteError => e
        Loom.log.error "wrapped SSHKit::Runner::ExecuteError, run with -d for more"
        Loom.log.error e.cause
        Loom.log.debug e.cause.backtrace.join "\n\t"
        Loom.log.debug1(self) { "Original error:" }
        Loom.log.debug1(self) { e.inspect }
        Loom.log.debug1(self) { e.backtrace.join "\n\t" }
        exit 97
      rescue Loom::LoomError => e
        Loom.log.error "Loom::LoomError => #{e.inspect}, run with -d for more"
        backtrace = e.cause.nil? ? e.backtrace : e.cause.backtrace
        Loom.log.debug backtrace.join "\n\t"
        Loom.log.debug backtrace.join "\n\t"
        exit 98
      rescue => e
        # TODO: Make error/exception logging look like this everywhere
        Loom.log.fatal "fatal error =>\n#{e.inspect}\n\t#{e.backtrace.join("\n\t\t")}"

        loom_files = @loom_config.files.loom_files
        loom_errors = e.backtrace.select { |line| line =~ /(#{loom_files.join("|")})/ }
        Loom.log.error "Loom file errors: \n\t" + loom_errors.join("\n\t")
        exit 99
      end
    end

    private

    def install_signal_traps
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

    def load
      @inventory_list =
        Loom::Inventory::InventoryList.active_inventory @loom_config
      @active_hosts = @inventory_list.hosts

      # TODO: the naming inconsistency between Pattern::Loader and
      # Mods::ModLoader bothers me... :(
      pattern_loader = Loom::Pattern::Loader.load @loom_config
      @pattern_refs = pattern_loader.patterns @pattern_slugs

      @loom_config[:loomfile_autoloads].each do |path|
        Loom.log.debug { "requiring config[:loomfile_autoloads]: #{path}" }
        require path
      end
      @mod_loader = Loom::Mods::ModLoader.new @loom_config
    end

    def run_internal(dry_run)
      # TODO: fix the bindings in the block below so we don't need
      # this alias
      inventory_list = @inventory_list

      on_host @active_hosts do |sshkit_backend, host_spec|
        hostname = host_spec.hostname

        begin
          @pattern_refs.each do |pattern_ref|
            if @caught_sig_int
              Loom.log.warn "caught SIGINT, skipping #{log_token(pattern_ref, hostname)}"
              next
            elsif inventory_list.disabled? hostname
              Loom.log.warn "host disabled due to previous failure, " +
                            "skipping: #{log_token(pattern_ref, hostname)}"
              next
            end

            # wip-patternbuilder is adding this feature
#            run_analysis_phase(pattern_ref, host_spec, sshkit_backend)
            run_execution_phase(pattern_ref, host_spec, sshkit_backend, dry_run)
          end
        rescue IOError => e
          # TODO: Try to patch SSHKit for a more specific error for unexpected
          # SSH disconnections
          Loom.log.error "unexpected SSH disconnect => #{hostname}"
          Loom.log.debug e
          handle_host_failure_strategy hostname, e.message
        rescue Errno::ECONNREFUSED => e
          Loom.log.error "unable to connect to host => #{hostname}"
          Loom.log.debug e
          handle_host_failure_strategy hostname, e.message
        end
      end
    end

    def run_execution_phase(pattern_ref, host_spec, sshkit_backend, dry_run)
      log_token = log_token(pattern_ref, host_spec.hostname)
      Loom.log.debug "collecting facts for => #{log_token}"
      # Collects facts for each pattern run on each host, this way if one
      # pattern run updates would be facts, the next pattern will see the
      # new fact.
      fact_shell = Loom::Shell.create @mod_loader, sshkit_backend, dry_run
      fact_set = Loom::Facts.fact_set(host_spec, fact_shell, @loom_config)
        .merge @other_facts

      Loom.log.info "running pattern => #{log_token}"
      # Creates a new shell for executing the pattern, so as not to be
      # tainted by the fact finding shell above.
      pattern_shell = Loom::Shell.create @mod_loader, sshkit_backend, dry_run

      Loom.log.warn "dry run only => #{log_token}" if dry_run
      failures = execute_pattern pattern_ref, pattern_shell, fact_set

      if failures.empty?
        Loom.log.debug "success on => #{log_token}"
      else
        Loom.log.error "failures on => #{log_token}:\n\t%s" % (
          failures.join("\n\t"))
      end
    end

    def execute_pattern(pattern_ref, shell, fact_set)
      shell_session = shell.session
      hostname = fact_set.hostname
      result_reporter = Loom::Pattern::ResultReporter.new(
        @loom_config, pattern_ref.slug, hostname, shell_session)

      # TODO: This is a crappy mechanism for tracking errors - hency my crappy
      # error reporting :( - there should be an exception thrown inside of Shell
      # when a command fails and pattern execution should stop. All errors
      # should come from exceptions. This needs to be thought about wrt to the
      # defined `failure_strategy`
      # @see the TODO at Loom::Shell::Core+test+
      run_failure = []
      begin
        pattern_ref.call(shell.shell_api, fact_set)
      rescue Loom::ExecutionError => e
        Loom.log.debug e.backtrace.join "\n\t"
        run_failure << e
      ensure
        # TODO[P0]: this prints out [Result: OK] even if an exception is
        # raised... this is really annoying.
        result_reporter.write_report

        # TODO: this is not the correct error condition.
        unless shell_session.success?
          run_failure << result_reporter.failure_summary
          handle_host_failure_strategy hostname, result_reporter.failure_summary
        end
        @result_reports << result_reporter
        @run_failures << run_failure unless run_failure.empty?
      end
      run_failure
    end

    def log_token(pattern_ref, hostname)
      slug = pattern_ref.slug
      "[#{hostname} => #{slug}]"
    end

    def handle_host_failure_strategy(hostname, failure_summary=nil)
      failure_strategy = @loom_config.run_failure_strategy.to_sym

      case failure_strategy
      when :exclude_host
        Loom.log.warn "disabling host per :run_failure_strategy => #{failure_strategy}"
        @inventory_list.disable hostname
      when :fail_fast
        Loom.log.error "erroring out of failed pattern per :run_failure_strategy"
        raise FailFastExecutionError, failure_summary
      when :cowboy
        Loom.log.warn "continuing on past failed pattern per :run_failure_strategy"
      else
        raise ConfigError, "unknown failure_strategy: #{failure_stratgy}"
      end
    end
  end
end
