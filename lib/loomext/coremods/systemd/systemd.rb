module LoomExt::CoreMods

  module SystemdCommon
    def do_systemctl(action, unit=nil, *args, flags: [])
      flags << "--no-pager"
      flags << "--no-legend"
      flags << "--no-ask-password"

      exec_args = [
        "systemctl",
        flags,
        action,
        unit
      ].flatten.compact
      args = exec_args.concat args
      shell.execute(*args)
    end
  end

  class Systemd < Loom::Mods::Module
    include SystemdCommon

    register_mod :systemd

    module Actions

      def is_loaded?(unit)
        status(unit).match? /^\s+Loaded:\sloaded\s/
      end

      def is_active?(unit)
        do_systemctl "is-active", unit
      end

      def status(unit)
        do_systemctl "status", unit
      end

      def enable(unit)
        do_systemctl "enable", unit
      end

      def start(unit)
        do_systemctl "start", unit
      end

      def disable(unit)
        do_systemctl "disable", unit
      end

      def restart(unit)
        do_systemctl "restart", unit
      end

      def stop(unit)
        do_systemctl "stop", unit
      end

      def link(path)
        do_systemctl "link", path
      end
    end
  end

  Systemd.import_actions Systemd::Actions
end
