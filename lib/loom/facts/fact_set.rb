module Loom::Facts

  class Provider
    attr_reader :fact_map

    class << self
      def register_factory(klass, &block)
        @provider_factories ||= []
        @provider_factories << block
        Loom.log.debug1(self) { "registered fact provider => #{klass}" }
      end

      def create_fact_providers(shell, loom_config)
        @provider_factories.map do |block|
          block.call(shell, loom_config)
        end.flatten
      end
    end

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
        fact_providers = Provider.create_fact_providers(shell, loom_config)
        fact_providers.each do |provider|
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

      @fact_map = YAML.load(fact_map.to_yaml)
      @hostname = host_spec.hostname
    end

    attr_reader :hostname

    def get(fact_name)
      @fact_map[fact_name.to_sym].dup rescue nil
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
