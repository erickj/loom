module Loom
  module Module

    AnonymousModLoadError = Class.new(StandardError)

    module ModBuilder
      attr_accessor :namespace

      def action(name, &block)
        action_id = define_action_handler name, &block
        puts "defined action %s" % [namespaced_action(name)]
      end

      def define_action_handler(name, &block)
        define_method name do |*args|
          puts "=> mod action: #{name}, args => #{args}"
          run_in_action_context self, *args, &block
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

      def run_in_action_context(mod, *args, &block)
        Loom::Context::ActionContext.run mod, *args, &block
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

      def run_in_action_context(mod, *args, &block)
        raise 'missing mod_context' unless @mod_context
        Loom::Context::ActionContext.run @mod_context, *args, &block
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
