# 10/21/2018: I resurrected this from an auto save file from a LOONNGGGG time
# ago., not really sure exactly what the original purpose is, but it has the
# code for uploading the harness script. I believe this was working at one
# point, but that was long ago

module Loom

  # Ensures loom is setup to run on the remote.
  # - creates the boostrap loom directory
  # - uploads the harness
  # - creates a directoy for loom execution logging
  class HostSession

    HISTORY_FILE = "command.log"

    # @param [Loom::HostSpec] host_spec
    # @param [Loom::Config] loom_config
    # @param [SSHKit::Backend::Abstract] sshkit_backend
    def initialize(host_spec, loom_config, sshkit_backend)
      @host_spec = host_spec
      @sshkit_backend = sshkit_backend
      @loom_config = loom_config

      @remote_loom_root = loom_config.bootstrap_loom_root
      @loom_user = loom_config.loom_user

      @session_name = "session.%d" % Time.now.to_i
      @disabled = false
    end

    attr_reader :session_name

    def bootstrap
      ensure_loom_remote_dirs
      ensure_harness_uploaded
      log_to_command_history "begin loom execution"
      log_to_command_history "start: " + Time.now.to_i.to_s
    end

    def disabled?
      @disabled
    end

    # @param [Loom::Pattern::Reference] pattern_ref
    # @return [Loom::Pattern::ExecResult]
    def execute_pattern(pattern_ref)
      shell = create_shell

      shell_session = shell.session
      result_reporter = Loom::Pattern::ResultReporter.new(
        @loom_config, pattern_ref.slug, hostname, shell_session)

      # TODO: This is a crappy mechanism for tracking errors, there should be an
      # exception thrown inside of Shell when a command fails and pattern
      # execution should stop. All errors should come from exceptions.
      run_failure = []
      begin
        fact_set = collect_facts_for_host
        pattern_ref.call(shell.shell_api, fact_set)
      rescue => e
        handle_host_failure e
      ensure
        # TODO: this prints out [Result: OK] even if an exception is raised
        result_reporter.write_report

        # TODO: this is not the correct error condition.
        unless shell_session.success?
          run_failure << result_reporter.failure_summary
          handle_host_failure result_reporter.failure_summary
        end
        @result_reports << result_reporter
        @run_failures << run_failure unless run_failure.empty?
      end
    end

    def handle_host_failure(error_or_message=nil)
      Loom.log.debug { "handling host failure => #{hostname}" }
      if error_or_message.respond_to? :backtrace
        Loom.log.debug { e.backtrace.join "\n\t" }
      end

      message = if error_or_message.respond_to? :message
                  error_or_message.message
                else
                  error_or_message
                end

      failure_strategy = @loom_config.run_failure_strategy.to_sym
      case failure_strategy
      when :exclude_host
        Loom.log.warn "disabling host due to failure => #{message}"
        @disabled = true
      when :fail_fast
        Loom.log.error "fail fast host failure => #{message}"
        raise FailFastExecutionError, message
      when :cowboy
        # This is mostly for testing, don't use in prod.
        Loom.log.warn "cowboy failure, wooohooo => #{message}"
      else
        raise ConfigError, "unknown failure_strategy: #{failure_stratgy}"
      end
    end

    private

    # @return [String]
    def script_path
      File.join @remote_loom_root, "scripts"
    end

    # @return [String]
    def session_path
      File.join @remote_loom_root, "run", @session_name
    end

    # @return [String]
    def history_file
      File.join session_name, HISTORY_FILE
    end

    def ensure_loom_remote_dirs
      @sshkit_backend.as user: :root do
        @sshkit_backend.execute :mkdir, '-p', @remote_loom_root
        @sshkit_backend.execute :mkdir, '-p', script_path
        @sshkit_backend.execute :mkdir, '-p', session_path

        chown_opts = "-R %s:%s %s" % [@loom_user, @loom_user, @remote_loom_root]
        @sshkit_backend.execute :chown, chown_opts
      end
    end

    def ensure_harness_uploaded
      @sshkit_backend.upload! Loom::Resource::HARNESS, script_path
    end

    def create_command_history
      @sshkit_backend :touch, history_file
    end

    def write_to_command_history(text)
      @sshkit_backend :cat, "<<EOS\n#{text}\nEOS", ">>", history_file
    end

    def log_to_command_history(text)
      write_to_command_history(
        "[%s] %s: #{text}" % [Time.now.utc.to_s, hostname])
    end

    # The naming inconsistency w/ the missing underscore in hostname (vs
    # host_spec, host_session, etc...) is confusing, but that's *nix's fault.
    def hostname
      @host_spec.hostname
    end

    def collect_facts_for_host
      Loom.log.info "collecting facts for host => #{hostname}"
      Loom::Facts.fact_set(@host_spec, create_shell, @loom_config)
    end

    def create_shell
      Loom::Shell.create create_mod_loader, @sshkit_backend
    end

    def create_mod_loader
      Loom::Mods::ModLoader.new loom_config
    end
  end
end
