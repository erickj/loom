module LoomExt::CoreMods

  class Systemd < Loom::Mods::Module

    register_mod :systemd

    def do_systemctl(action, *args)
      shell.execute "systemctl", action, *args
    end

    module Actions

      def is_loaded?(unit)
        status(unit).match? /^\s+Loaded:\sloaded\s/
      end

      def is_active?(unit)
        status(unit).match? /^\s+Active:\sactive\s/
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
