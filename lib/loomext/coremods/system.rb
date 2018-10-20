module LoomExt::CoreMods

  class System < Loom::Mods::Module
    register_mod :status do |unit, **opts|
      shell.execute "systemctl", "status", unit
    end
  end
end
