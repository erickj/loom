module Loom
  module Module

    AnonymousModLoadError = Class.new(StandardError)

    module ModBuilder
      attr_accessor :namespace

      def action(name, &action_body)
        action_id = define_action_handler name, &action_body
        puts "defined action %s" % [namespaced_action(name)]
      end

      def define_action_handler(name, &action_body)
        define_method name do |*args, &inner_block|
          puts "=> mod action: #{name}, args => #{args}, inner_block => #{inner_block}"
          Loom::Context::ActionContext.run(
            action_binding_scope, inner_block, *args, &action_body)
          self
        end
      end

      def namespaced_action(action_name)
        [namespace, action_name].compact.join ":"
      end

      def ns(name, &block)
        klass = Class.new NamespacedMod
        klass.namespace = name

        ns_id = define_namespace_handler name, klass
        puts "defined namespace #{name}"
        klass.instance_exec &block
      end

      def define_namespace_handler(name, namespaced_mod_klass)
        define_method name do |*args, &block|
          namespaced_mod_klass.new self
        end
      end
    end

    class AbstractMod
      attr_accessor :shell, :mods

      class << self
        include ModBuilder
      end

      def action_binding_scope
        self
      end
    end

    class Mod < AbstractMod
      def self.inherited(klass)
        ModLoader.register_module klass
      end
    end

    class NamespacedMod < AbstractMod
      def initialize(mod_context)
        @mod_context = mod_context
      end

      def action_binding_scope
        raise 'missing mod_context' unless @mod_context
        @mod_context
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
        def define_mod_factory(name, klass)
          puts "defined_mod_factory #{name}"
          define_method name do |*args|
            mod = klass.new *args
            # self is a ModuleLoader
            mod.shell = @shell
            mod.mods = self 
            mod
          end
        end

        def register_module(klass)
          raise AnonymousModLoadError, 'cannot load anonymous mods' unless klass.name

          define_mod_factory klass.to_s.underscore.to_sym, klass
          define_mod_factory klass.to_s.demodulize.underscore.to_sym, klass
        end
      end
    end
  end
end
