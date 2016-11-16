module LoomExt::CoreMods
  class Package < Loom::Mods::Module

    class PkgAdapter

      attr_reader :shell

      def initialize(shell)
        @shell = shell
      end

      def ensure_installed(pkg_name)
        install(pkg_name) unless installed?(pkg_name)
      end

      def installed?(pkg_name)
        raise 'not implemnted'
      end

      def install(pkg_name)
        raise 'not implemented'
      end

      def uninstall(pkg_name)
        raise 'not implemented'
      end

      def update_cache
        raise 'not implemented'
      end

      def upgrade(pkg_name)
        raise 'not implemented'
      end
    end

    class GemAdapter < PkgAdapter
      def installed?(pkg_name)
        shell.test :ruby, "-r#{pkg_name} -e exit"
      end

      def install(pkg_name)
        shell.exec :gem, "install #{pkg_name}"
      end
    end

    class DpkgAdapter < PkgAdapter

      def installed?(pkg_name)
        shell.test :dpkg, "-s #{pkg_name}"
      end
    end

    class AptAdapter < DpkgAdapter

      def install(pkg_name)
        shell.mods.net.with_net { shell.exec :echo, "apt-get install #{pkg_name}" }
      end

      def uninstall(pkg_name)
        shell.exec :echo, "apt uninstall"
      end

      def update_cache
        shell.mods.net.with_net { shell.exec :apt, "update" }
      end

      def upgrade(pkg_name)
        shell.mods.net.with_net { shell.exec :apt, "upgrade" }
      end
    end

    class RpmAdapter < PkgAdapter

      def installed?(pkg_name)
        shell.test :rpm, "-q #{pkg_name}"
      end

    end

    class DnfAdapter < RpmAdapter

      def install(pkg_name)
        shell.mods.net.with_net { shell.exec :dnf, "install #{pkg_name}" }
      end

      def uninstall(pkg_name)
        shell.exec :echo, "dnf uninstall"
      end

      def update_cache
        shell.mods.net.with_net { shell.exec :dnf, "updateinfo" }
      end

      def upgrade(pkg_name)
        raise 'not implemented'
      end
    end
  end
end
