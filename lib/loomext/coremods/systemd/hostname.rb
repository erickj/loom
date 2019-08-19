module LoomExt::CoreMods

  class Hostname < Loom::Mods::Module
    include SystemdCommon

    register_mod :sethostname do |**opts|
      shell.execute :hostnamectl, **opts
    end
  end
end
