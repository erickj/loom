module Loom
  module Module

    NotLoaded = Class.new(StandardError)

    class Mod

      attr_accessor :shell, :mods

      class << self

        def action(name, &block)
          define_action_method name, &block
        end

        def define_action_method(name, &block)
          define_method name do |*args|
            self.instance_exec(*args, &block)
            self
          end
          puts "defined method #{name}"
        end

        def inherited(klass)
          ModuleLoader.register_module klass
        end

      end
    end

    ##
    # Singleton class for register and creating mods dynamically
    class ModuleLoader

      def initialize(shell)
        @shell = shell
      end

      class << self
        def define_mod_factory(name, klass)
          puts "defined_mod_factory #{name}"
          define_method name do |*args|
            mod = klass.new(*args)
            # self is a ModuleLoader
            mod.shell = @shell
            mod.mods = self 
            mod
          end
        end

        def register_module(klass)
          define_mod_factory klass.to_s.underscore.to_sym, klass
          define_mod_factory klass.to_s.demodulize.underscore.to_sym, klass
        end
      end
    end
  end
end
