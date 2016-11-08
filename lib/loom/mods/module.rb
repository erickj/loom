module Loom::Mods

  ModActionError = Class.new Loom::LoomError

  class Module
    attr_accessor :shell, :action_proxy, :exec_args

    def initialize(shell, *args)
      @shell = shell
      @exec_args = args
      @action_proxy = self.class.action_proxy self
    end

    class << self

      def register_mod(name, **opts, &block)
        ModLoader.register_mod self, name, **opts, &block
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
      def action_proxy(mod)
        @action_proxy_klasses ||= {}
        @action_proxy_klasses[mod.class.hash] ||=
          ActionProxy.subclass_for_action_map action_map
        @action_proxy_klasses[mod.class.hash].new mod
      end

      private
      def action_map
        @action_map ||= ActionProxy.new_action_map
      end
    end

  end
end
