module Loom::Pattern
  class ResultReporter
    def initialize(pattern_slug, host, shell_session)
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
      "[Result: #{status}] (#{@host.hostname}) => (#{@pattern_slug})"
    end

    def generate_report
      cmds = @shell_session.command_results

      report = ["-------"]
      report << "#{scenario_string}"
      report << "Completed in: %01.3fs" % @delta_t

      unless success?
        failure_cmds = cmds.select { |c| !c.success? }
        failure_cmds.each do |failed_cmd|
          report.concat generate_failure_report(failed_cmd)
        end
      end

      report
    end

    def generate_failure_report(cmd)
      report = []
      report << "-------"
      report << "$ #{cmd.command}"
      report << "exit status: #{cmd.exit_status}"

      unless cmd.stdout.empty?
        report << "stdout:"
        report << cmd.stdout
      end

      unless cmd.stderr.empty?
        report << "stderr:"
        report << cmd.stderr
      end

      report
    end
  end
end
