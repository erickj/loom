module LoomExt::CoreMods
  class Git < Loom::Mods::Module

    register_mod :git
    required_commands :git

    module Actions
      def push
        shell.execute :git, :push
      end

      def pull
        shell.execute :git, :pull
      end
    end
  end

  Git.import_actions Git::Actions
end
