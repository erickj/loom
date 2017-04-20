module Loom
  module Shell

    class HarnessCommandBuilder < CommandBuilder

      DEFAULT_RUN_OPTS = {
        :cmd_shell => "/bin/dash",
      }

      HARNESS_OP = {
        :run => "run",
        :check => "check"
      }

      def initialize(harness_script)
        @run_opts = DEFAULT_RUN_OPTS.dup
      end

      def run_cmd
        build_cmd HARNESS_OP[:run], @cmd.checksum, *hash_to_opts_array(@run_opts),
                  @cmd.encoded_script
      end

      def check_cmd
        build_cmd HARNESS_OP[:check], @cmd.checksum, @cmd.encoded_script
      end

      private
      def hash_to_opts_array(hash)
        hash.to_a.map do |tuple|
          "--%s %s" % [tuple.first, tuple.last]
        end
      end

      def build_cmd(harness_op, *args, cmd)
        heredoc_id = "HARNESS_BASE64_" + Time.now.to_i.to_s
        heredoc = "<<'#{heredoc_id}'\n#{cmd}\n#{heredoc_id}"
        "%s --%s 2>/dev/null - %s %s" % [
          HARNESS,
          harness_op,
          args.join(" "),
          heredoc
        ]
      end
    end
  end
end
