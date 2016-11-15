module Loom::Facts

  class Provider
    attr_reader :fact_map

    class << self
      def disable_for_host(host_spec, klass)
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
      Loom.log.warn "disabling fact provider => #{self}"
      Provider.disable_for_host host_spec, self.class
    end

    # Should return a Hash
    def collect_facts
      raise 'not implemented'
    end
  end

  class FactSet

    InvalidFactName = Class.new Loom::LoomError
    InvalidFactValue = Class.new Loom::LoomError
    UnmarshalableError = Class.new Loom::LoomError

    class << self
      def create_for_host(host_spec, shell, loom_config)
        fact_map = {}
        fact_providers = Provider.create_fact_providers(host_spec, shell, loom_config)
        fact_providers.each do |provider|
          next if Provider.disabled_for_host?(host_spec, provider.class)

          Loom.log.debug(self) { "loading facts from provider => #{provider}" }
          provider.collect_facts.each do |k, v|
            k = k.to_sym
            if fact_map[k]
              Loom.log.warn "overriding fact => #{k}"
            end
            Loom.log.debug3(self) { "adding fact => #{k}=#{v.to_s}" }
            fact_map[k] = v
          end
        end

        FactSet.new host_spec, fact_map
      end
    end

    def initialize(host_spec, fact_map)
      raise unless fact_map.is_a? Hash
      validate_facts fact_map

      @fact_map = YAML.load(fact_map.to_yaml).reduce({}) do |memo, tuple|
        memo[tuple.first.to_sym] = tuple.last
        memo
      end
      @host_spec = host_spec
    end

    attr_reader :host_spec

    def merge(facts)
      facts = case facts
              when FactSet
                facts.facts
              when Hash
                facts
              else
                raise "unable to merge facts => #{facts.class}:#{facts}"
              end
      merged_facts = @fact_map.merge facts
      FactSet.new @host_spec, merged_facts
    end

    def hostname
      host_spec.hostname
    end

    def get(fact_name)
      result = @fact_map[fact_name.to_sym]
      result.dup rescue result
    end
    alias_method :[], :get

    def facts
      @fact_map.dup
    end

    def to_s
      @fact_map.to_a.map { |tuple| tuple.join "=" }.join "\n"
    end

    private
    def validate_facts(fact_map)
      fact_map.each do |k, v|
        validate_fact_name k.to_sym
        validate_fact_value v
      end
      raise UnmarshalableError unless fact_map.eql? YAML.load(fact_map.to_yaml)
    end

    def validate_fact_name(name)
      raise InvalidFactName, name unless name.eql? YAML.load(name.to_yaml)
    end

    def validate_fact_value(value)
      raise InvalidFactValue, value unless value.eql? YAML.load(value.to_yaml)
    end
  end
end
