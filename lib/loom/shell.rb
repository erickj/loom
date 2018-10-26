module Loom
  module Shell

    VerifyError = Class.new Loom::LoomError

    class << self
      def create(mod_loader, sshkit_backend, dry_run, no_exec: false)
        Loom::Shell::Core.new mod_loader, sshkit_backend, dry_run
      end
    end
  end
end

require_relative "shell/all"
