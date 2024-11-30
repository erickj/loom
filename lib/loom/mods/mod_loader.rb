module Loom::Mods

  AliasRegisteredError = Class.new Loom::LoomError
  AnonymousModLoadError = Class.new Loom::LoomError
  ModDefinedError = Class.new Loom:: LoomError
  ModNotRegisteredError = Class.new Loom::LoomError

  class ModLoader
    def initialize(loom_config)
      @loom_config = loom_config
    end

    def load_mod_klass(mod_klass, shell)
      verify_shell_cmds mod_klass, shell
    end

    private
    def verify_shell_cmds(mod_klass, shell)
      Loom.log.debug2(self) { "verifying cmds for mod => #{mod_klass}" }
      mod_klass.required_commands.each do |cmd|
        begin
          shell.verify_which cmd
        rescue Loom::Shell::VerifyError
          Loom.log.error "unable to use mod #{mod_klass}, missing required command => #{cmd}"
          raise $!
        end
      end
    end

    class << self

      def register_mod(klass, name, **opts)
        name = name.to_sym
        raise AnonymousModLoadError, 'cannot load anonymous mods' unless name
        raise ModDefinedError, name if instance_methods.include? name

        define_mod_factory name, klass
        Loom.log.debug(self) { "registered mod => #{klass} as #{name}" }

        opts.each do |k,v|
          case k
          when :alias
            [v].flatten.each { |v| alias_module klass, v }
          else
            raise "unknown option #{k}"
          end
        end
      end

      # TODO: add some documentation here, this is the entrypoint for all mod
      # factories and returning the ActionProxy or running a ModBlock. This is
      # just as hidden as ActionProxy+install_root_actions+
      def define_mod_factory(name, mod_klass)
        raise ModDefinedError, name if instance_methods.include? name
        registered_mods[mod_klass.name] = [name]

        define_method name do |shell, *args, **kwargs, &pattern_block|
          Loom.log.debug3(self) do
            "handling mod call => #{mod_klass}##{name} #{args} #{kwargs} #{pattern_block}"
          end
          load_mod_klass mod_klass, shell

          mod = mod_klass.new shell, @loom_config
          mod.execute *args, **kwargs, &pattern_block
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
