module Loom::Facts

  ##
  # A factset is created by running each registered Loom::Facts::Provider and
  # calling Provider+collect_facts+. See ./fact_file_provider.rb and
  # lib/loomext/facts/facter_provider.rb for examples of fact providers.
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

          Loom.log.debug { "loading facts from provider => #{provider}" }

          begin
            provider.collect_facts.each do |k, v|
              k = k.to_sym
              if fact_map[k]
                Loom.log.warn "overriding fact => #{k}"
              end
              Loom.log.debug5(self) { "adding fact => #{k}=#{v.to_s}" }
              fact_map[k] = v
            end
          rescue => e
            Loom.log.error "error executing fact provider #{provider.class} => #{e.message}"
            provider.disable(host_spec)
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
