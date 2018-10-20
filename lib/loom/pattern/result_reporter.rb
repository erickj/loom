module Loom::Pattern
  class ResultReporter
    def initialize(loom_config, pattern_slug, hostname, shell_session)
      @loom_config = loom_config
      @start = Time.now
      @delta_t = nil
      @hostname = hostname
      @pattern_slug = pattern_slug
      @shell_session = shell_session
    end

    attr_reader :hostname

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
      "#{hostname} => #{@pattern_slug} [Result: #{status}] "
    end

    def generate_report
      cmds = @shell_session.command_results

      report = ["--- #{scenario_string}"]
      report << "Completed in: %01.3fs" % @delta_t

      cmds.find_all { |cmd| !cmd.is_test }.each do |cmd|
        # TODO: this is a bit confusing for the user... when you cat a file from
        # a loom pattern, the output of a command isn't visible unless -V is
        # specified... not sure what to do here. I don't want to see the output
        # of every command, and I don't really want to pipe more info through
        # the `@shell_session.command_results` (e.g. should_report_result:)?
        #
        # Although.. maybe that's the better API? then the logic here can be
        # moved and strategized per command/result/shell.
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
