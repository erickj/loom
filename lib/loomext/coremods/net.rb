module LoomExt::CoreMods
  class Net < Loom::Mods::Module

    NoNetworkError = Class.new Loom::ExecutionError

    register_mod :net

    def initialize(shell, timeout: 10, check_host: "8.8.8.8")
      super shell
      @net_timeout = timeout
      @check_host = check_host
    end

    module Actions

      def has_net?
        shell.mods.timeout :timeout => @net_timeout do
          shell.exec "ping -c 1 #{@check_host}"
        end
      end

      def check_net
        raise NoNetworkError, "no network available" unless has_net?
      end

      def with_net(&block)
        check_net
        yield if block_given?
      end
    end

    import_actions Net::Actions
  end
end
