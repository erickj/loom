module Loom::Mods

  AliasRegisteredError = Class.new Loom::LoomError
  AnonymousModLoadError = Class.new Loom::LoomError
  ModDefinedError = Class.new Loom:: LoomError
  ModNotRegisteredError = Class.new Loom::LoomError

  ##
  # Singleton class for registering and creating mods dynamically
  class ModLoader
    def initialize(shell)
      @shell = shell
    end

    def verify_shell_cmds(mod_klass)
      Loom.log.debug2(self) { "verifying cmds for mod => #{mod_klass}" }
      mod_klass.required_commands.each do |cmd|
        begin
          @shell.verify_which cmd
        rescue Loom::Shell::VerifyError
          Loom.log.error "unable to use mod #{mod_klass}, missing required command => #{cmd}"
          raise $!
        end
      end
    end

    class << self

      def register_mod(klass, name, **opts, &block)
        name = name.to_sym
        raise AnonymousModLoadError, 'cannot load anonymous mods' unless name
        raise ModDefinedError, name if instance_methods.include? name

        define_mod_factory name, klass, &block
        Loom.log.debug1(self) { "registered mod => #{klass} as #{name}" }

        opts.each do |k,v|
          case k
          when :alias
            [v].flatten.each { |v| alias_module klass, v }
          else
            raise "unknown option #{k}"
          end
        end
      end

      def define_mod_factory(name, mod_klass, &block)
        raise ModDefinedError, name if instance_methods.include? name
        registered_mods[mod_klass.name] = [name]

        define_method name do |*args, &inner_block|
          Loom.log.debug3(self) do
            "handling mod call => #{mod_klass}##{name} #{args} #{inner_block}"
          end
          verify_shell_cmds mod_klass

          if block
            mod = mod_klass.new @shell
            block.call mod, *args, &inner_block
          else
            mod = mod_klass.new @shell, *args
            mod.action_proxy
          end
        end
      end

      def registered_mods
        @registered_mods ||= {}
      end

      private
      def alias_module(klass, alias_name)
        raise ModNotRegisteredError, klass unless registered_mods[klass.name]
        raise AliasRegisteredError, alias_name if instance_methods.include? alias_name

        original_method = registered_mods[klass.name].first
        registered_mods[klass.name] << alias_name

        alias_method alias_name.to_sym, original_method
        Loom.log.debug1(self) { "mod aliased => #{original_method} as #{alias_name}" }
      end
    end
  end
end
