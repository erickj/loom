module LoomExt::CoreMods
  class Package < Loom::Mods::Module

    class PkgAdapter

      attr_reader :loom

      def initialize(loom)
        @loom = loom
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
        loom.test "ruby -r#{pkg_name} -e exit"
      end

      def install(pkg_name)
        loom.x :gem, :install, pkg_name
      end
    end

    class DpkgAdapter < PkgAdapter

      def installed?(pkg_name)
        loom.test "dpkg -s #{pkg_name}"
      end
    end

    class AptAdapter < DpkgAdapter

      def install(pkg_name)
        loom.x "apt-get", "-y", "install", pkg_name
#        loom.net.with_net { loom << "echo apt-get install #{pkg_name}" }
      end

      def uninstall(pkg_name)
        loom << "echo apt uninstall"
      end

      def update_cache
#        loom.net.with_net { loom << "apt update" }
        loom.x "apt", "-y", "update"
      end

      def upgrade(pkg_name = nil)
#        loom.net.with_net { loom << "apt upgrade" }
        args = ["apt-get", "-y", "upgrade", pkg_name].compact
        loom.x(*args)
      end
    end

    class RpmAdapter < PkgAdapter

      def installed?(pkg_name)
        loom.test :rpm, "-q #{pkg_name}"
      end

    end

    class DnfAdapter < RpmAdapter

      def install(pkg_name)
        loom.net.with_net { loom << "dnf install #{pkg_name}" }
      end

      def uninstall(pkg_name)
        # TODO: fix all loom.execute calls w/ properly atomized params
        loom << "echo dnf uninstall"
      end

      def update_cache
        loom.net.with_net { loom << "dnf updateinfo" }
      end

      def upgrade(pkg_name)
        raise 'not implemented'
      end
    end
  end
end
