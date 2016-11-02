module Loom::Mods

  AnonymousModLoadError = Class.new(StandardError)

  class Module
    attr_accessor :shell, :mods
    alias_method :_, :shell

    class << self
      def inherited(klass)
        ModLoader.register_module klass
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
          bound_method = unbound_method.bind self
          bound_method.call *args, &block
          self
        end
        puts "bound action #{action_name}"

        bound_method_name
      end

      def action_proxy(mod)
        @action_proxy_klass ||= ActionProxy.subclass_for_action_map action_map
        @action_proxy_klass.new mod
      end

      private
      def action_map
        @action_map ||= ActionProxy.new_action_map
      end
    end

  end

  ##
  # Singleton class for register and creating mods dynamically
  class ModLoader
    using Loom::CoreExt # for String#underscore and String#demodulize

    def initialize(shell)
      @shell = shell
    end

    class << self
      def define_mod_factory(name, mod_klass)
        define_method name do |*args|
          mod = mod_klass.new *args

          # self is a ModuleLoader
          mod.shell = @shell
          mod.mods = self 

          mod_klass.action_proxy(mod)
        end
        puts "defined_mod_factory #{name}"
      end

      def register_module(klass)
        raise AnonymousModLoadError, 'cannot load anonymous mods' unless klass.name

        define_mod_factory klass.to_s.underscore.to_sym, klass
        define_mod_factory klass.to_s.demodulize.underscore.to_sym, klass
      end
    end
  end
end
