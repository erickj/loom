module Loom
  module Shell

    HarnessMissingStdin = Class.new Loom::LoomError

    class HarnessCommandBuilder

      # TODO: Resolve a real script path.
      SCRIPT = "./scripts/harness.sh"

      DEFAULT_RUN_OPTS = {
        :cmd_shell => "/bin/dash",
        :record_file => "/opt/loom/commands"
      }

      def initialize(harness_blob)
        @harness_blob = harness_blob
        @run_opts = DEFAULT_RUN_OPTS.dup
      end

      def run_cmd
        build_cmd :run, @harness_blob.checksum, *hash_to_opts_array(@run_opts),
                  {
                    :stdin => @harness_blob.encoded_script
                  }
      end

      def check_cmd
        build_cmd :check, @harness_blob.checksum, {
                    :stdin => @harness_blob.encoded_script
                  }
      end

      private
      def hash_to_opts_array(hash)
        hash.to_a.map do |tuple|
          "--%s %s" % [tuple.first, tuple.last]
        end
      end

      def build_cmd(cmd, *args, stdin: nil)
        raise HarnessMissingStdin unless stdin

        heredoc = "<<'HARNESS_EOS'\n#{stdin}\nHARNESS_EOS"
        cmd = "--" + cmd.to_s
        "%s %s 2>/dev/null - %s %s" % [SCRIPT, cmd, args.join(" "), heredoc]
      end
    end
  end
end
