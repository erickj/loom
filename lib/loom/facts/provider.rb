module Loom::Facts

  class Provider
    # TODO: add documentation re: use of namespace in fact_set.rb
    attr_reader :fact_map, :namespace

    class << self
      def disable_for_host(host_spec, klass)
        Loom.log.warn "disabling fact provider => #{klass} on #{host_spec.hostname}"
        @disabled_providers ||= {}
        @disabled_providers[host_spec.hostname] ||= []
        @disabled_providers[host_spec.hostname] << klass
      end

      def disabled_for_host?(host_spec, klass)
        @disabled_providers ||= {}
        @disabled_providers[host_spec.hostname] ||= []
        @disabled_providers[host_spec.hostname].include? klass
      end

      def register_factory(klass, &block)
        @provider_factories ||= []
        @provider_factories << block
        Loom.log.debug1(self) { "registered fact provider => #{klass}" }
      end

      def create_fact_providers(host_spec, shell, loom_config)
        @provider_factories.map do |block|
          block.call(host_spec, shell, loom_config)
        end.flatten
      end
    end

    def disable(host_spec)
      Provider.disable_for_host host_spec, self.class
    end

    # Should return a Hash of fact_name => fact_value entries
    def collect_facts
      raise 'not implemented'
    end
  end
end
