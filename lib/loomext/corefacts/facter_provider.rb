module LoomExt::CoreFacts
  class FacterProvider < Loom::Facts::Provider

    Loom::Facts::Provider.register_factory(self) do |host_spec, shell, loom_config|
      FacterProvider.new host_spec, shell
    end

    def initialize(host_spec, shell)
      @has_facter = shell.test :which, "facter"
      disable(host_spec) unless @has_facter
      @shell = shell
    end

    def collect_facts
      unless @has_facter
        Loom.log.error "facter not installed"
        return {}
      end

      yaml_facts = @shell.capture "facter --yaml"
      YAML.load yaml_facts
    end
  end
end
