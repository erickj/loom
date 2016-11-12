module LoomExt::CoreFacts
  class FacterProvider < Loom::Facts::Provider

    Loom::Facts::Provider.register_factory(self) do |shell, loom_config|
      FacterProvider.new shell
    end

    def initialize(shell)
      @has_facter = shell.test :which, "facter"
      @shell = shell
    end

    def collect_facts
      unless @has_facter
        Loom::Log.warn "facter not installed"
        return {}
      end

      yaml_facts = @shell.capture "facter --yaml"
      YAML.load yaml_facts
    end
  end
end
