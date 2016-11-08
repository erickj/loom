module Loom::Pattern
  class ResultReporter
    def initialize(loom_config, pattern_slug, host, shell_session)
      @loom_config = loom_config
      @start = Time.now
      @delta_t = nil
      @host = host
      @pattern_slug = pattern_slug
      @shell_session = shell_session
    end

    def failure_summary
      return "scenario did not fail" if success?
      scenario_string
    end

    def write_report
      @delta_t = Time.now - @start

      report = generate_report.join "\n\t"
      if success?
        Loom.log.info report
      else
        Loom.log.warn report
      end
    end

    private
    def success?
      @shell_session.success?
    end

    def scenario_string
      status = success? ? "OK" : "FAILED"
      "#{@host.hostname} => #{@pattern_slug} [Result: #{status}] "
    end

    def generate_report
      cmds = @shell_session.command_results

      report = ["--- #{scenario_string}"]
      report << "Completed in: %01.3fs" % @delta_t

      cmds.find_all { |cmd| !cmd.is_test }.each do |cmd|
        if !cmd.success? || @loom_config.run_verbose
          report.concat generate_cmd_report(cmd)
        end
      end

      report
    end

    def generate_cmd_report(cmd)
      status = cmd.success? ? "Success" : "Failed"

      report = []
      report << ""
      report << "--- #{status} Command ---"
      report << "$ #{cmd.command}"

      unless cmd.stdout.empty?
        report << cmd.stdout
      end

      unless cmd.stderr.empty?
        report << "[STDERR]:"
        report << cmd.stderr
      end

      report << "[EXIT STATUS]: #{cmd.exit_status}"

      report
    end
  end
end
