module Loom::Mods

  ModActionError = Class.new Loom::LoomError
  InvalidModActionSignature = Class.new Loom::LoomError

  class Module
    attr_accessor :shell, :loom_config, :loom, :mods, :action_proxy

    def initialize(shell, loom_config)
      unless shell && shell.is_a?(Loom::Shell::Core)
        raise "missing shell for mod #{self} => #{shell}"
      end
      unless loom_config && loom_config.is_a?(Loom::Config)
        raise "missing config for mod #{self} => #{loom_config}"
      end

      @shell = shell
      @loom = shell.shell_api
      @mods = shell.mod_loader
      @loom_config = loom_config

      # The action proxy is a facade for the mod provided to patterns by the
      # ShellApi (the 'loom' object). The ShellApi calls back to the mod_loader
      # on method missing which instantiates a new Module object and returns the
      # action_proxy.
      @action_proxy = self.class.action_proxy self, shell.shell_api
      @action_args = nil
      @action_block = nil
    end

    def init_action(*args, &pattern_block)
      @action_args = args
      @action_block = pattern_block
    end

    def execute(*args, &pattern_block)
      if respond_to? :mod_block
        Loom.log.debug3(self) { "executing mod block => #{args} #{pattern_block}" }
        mod_block *args, &pattern_block
      else
        Loom.log.debug3(self) { "initing action => #{args}" }
        init_action *args, &pattern_block

        # TODO: ooohhh... the action_proxy code path is fucking
        # crazy. ActionProxy needs some documentation.
        action_proxy
      end
    end

    class << self

      ##
      # Registers a mod as a new namespace on the loom object.
      # Mods add actions either via a `mod_block` or via registering
      # actions. Only 1 mod_block may be registered per module (which should
      # be fixed), otherwise actions are imported to add module behavior.
      # See loom/lib/loomext/coremods.rb and files.rb for examples.
      def register_mod(name, **opts, &block)
        Loom.log.debug2(self) { "registered mod => #{name}" }

        # TODO: allow multiple mod_blocks per mod. Should probably stop
        # dynamically defining :mod_block to do so. Current behavior, is the
        # last register_mod w/ a mod_block wins. This is obvsiously shitty.
        if block_given?
          Loom.log.debug2(self) { "acting as mod_block => #{name}:#{block}" }
          define_method :mod_block, &block
        end

        # TODO: Currently registering a block for a mod is different than
        # importing actions because of how the mod gets executed. When actions
        # are imorted, the mod is treated as an object providing access to the
        # actions (via the action_proxy), the action proxy is provided to the
        # calling pattern via {#execute}. When a block is registered, then the
        # mod is only a sinlge method executed immediately via #{execute}. The
        # method signature for the block and action proxy method are the
        # same... this should be simplified.
        ModLoader.register_mod self, name, **opts
      end

      def required_commands(*cmds)
        @required_commands ||= []
        @required_commands.push *cmds unless cmds.empty?
        @required_commands
      end

      def import_actions(action_module, namespace=nil)
        action_module.instance_methods.each do |action_name|
          bound_method_name = bind_action(
            action_name, action_module.instance_method(action_name), namespace)

          action_map.add_action action_name, bound_method_name, namespace
        end
      end

      def bind_action(action_name, unbound_method, namespace=nil)
        bound_method_name = [namespace, action_name].compact.join '_'

        # TODO: document why the `define_method` calls in class only operate on
        # the single mod instance, rather than adding each "bound_method_name"
        # (e.g.) to each instance of Module. (actually I think it's because this
        # is executing from the subclass (via import_actions), so it's only that
        # class). in any case, add more docs and code pointers.
        define_method bound_method_name do |*args, &block|
          Loom.log.debug1(self) { "exec mod action #{self.class}##{bound_method_name}" }

          bound_method = unbound_method.bind self
          bound_method.call *args, &block
        end
        Loom.log.debug2(self) { "bound mod action => #{self.class.name}##{action_name}" }

        bound_method_name
      end

      ##
      # This needs more thought
      def action_proxy(mod, shell_api)
        @action_proxy_klasses ||= {}
        @action_proxy_klasses[mod.class.hash] ||=
          ActionProxy.subclass_for_action_map action_map
        @action_proxy_klasses[mod.class.hash].new mod, shell_api
      end

      private
      def action_map
        @action_map ||= ActionProxy.new_action_map
      end
    end

  end
end
