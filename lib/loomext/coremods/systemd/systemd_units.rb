module LoomExt::CoreMods

  module SystemdUnitsCommon

    def init_action(*units, type: nil)
      @units = units
      @type = type
    end

    def do_systemctl_list(list_what, flags=common_list_flags)
      do_systemctl("list-%s" % list_what, flags: flags)
    end

    def common_list_flags
      ["--plain", "--full", "--all"]
    end
  end

  class SystemdUnits < Loom::Mods::Module
    include SystemdCommon
    include SystemdUnitsCommon

    register_mod :systemd_units

    module Actions
      def list
        do_systemctl_list :units
      end

      def status
        @units.map do |unit|
          do_systemctl "status", unit, flags: ["--output=short-unix"]
        end
      end
    end

    import_actions Actions
  end

  class SystemdSockets < SystemdUnits
    include SystemdCommon
    include SystemdUnitsCommon

    register_mod :systemd_sockets

    module Actions
      def list
        do_systemctl_list :sockets
      end
    end

    import_actions Actions
  end

  class SystemdTimers < SystemdUnits
    include SystemdCommon
    include SystemdUnitsCommon

    register_mod :systemd_timers

    module Actions
      def list
        do_systemctl_list :timers
      end
    end

    import_actions Actions
  end
end
