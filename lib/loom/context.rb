module Loom
  class Context

    attr_accessor :shell, :mods, :host

    def initialize(shell, mods, host)
      @shell = shell
      @mods = mods
      @host = host
    end

    class << self
      def run(shell, mods, host, &block)
        context = self.new(shell, mods, host)
        shell.instance_exec(context, &block)
      end
    end

  end
end
