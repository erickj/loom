module Loom::Facts

  class Provider
    attr_reader :fact_map

    class << self
      # TODO: There is a bug here, all provider instances of the same class will
      # be disabled on this call. Currently each provider klass is only
      # registered once though.
      def disable_for_host(host_spec, klass)
        Loom.log.warn(
          "disabling fact provider => #{klass} on #{host_spec.hostname}")
        @disabled_providers ||= {}
        @disabled_providers[host_spec.hostname] ||= []
        @disabled_providers[host_spec.hostname] << klass
      end

      def disabled_for_host?(host_spec, klass)
        @disabled_providers ||= {}
        @disabled_providers[host_spec.hostname] ||= []
        @disabled_providers[host_spec.hostname].include? klass
      end

      def register_provider(provider)
        unless provider.respond_to? :collect_facts
          raise "provider must respond to collect_facts"
        end
        @provider_instances ||= []
        @provider_instances << provider
        Loom.log.debug1(self) { "registered fact provider => #{provider}" }
      end

      # TODO: This is crappy, klass is useless here other than for logging. Kill
      # this is favor of #{register_provider} somehow.
      def register_factory(klass, &block)
        @provider_factories ||= []
        @provider_factories << block
        Loom.log.debug1(self) { "registered fact provider factory => #{klass}" }
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

    # @return [Hash]
    def collect_facts
      raise 'not implemented'
    end
  end

  class HashFactProvider < Provider

    class << self
      def create_and_register(fact_hash)
        Provider.register_provider HashProvider.new(fact_hash)
      end
    end

    def initialize(fact_hash)
      @fact_hash = fact_hash
    end

    def collect_facts
      @fact_hash.dup
    end
  end

  class FactSet

    # If you can't serialize a fact, then it's invalid. Facts are validated by
    # marshalling names, values, and the entire hash through #{YAML.load}, the
    # inputs and outputs must be #{eql?}.
    InvalidFactName = Class.new Loom::LoomError
    InvalidFactValue = Class.new Loom::LoomError
    UnmarshalableError = Class.new Loom::LoomError

    class << self
      def create_for_host(host_spec, shell, loom_config)
        fact_map = {}
        fact_providers =
          Provider.create_fact_providers(host_spec, shell, loom_config)
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
            Loom.log.error(
              "error executing fact provider #{provider.class} => #{e.message}")
            provider.disable(host_spec)
          end
        end

        FactSet.new host_spec, fact_map
      end
    end

    # TODO: This shouldn't require a host_spec, that's a poor abstraction, a
    # HostSession should have a FactSet, not vice-versa. This is the way it is
    # because I was lazy when disabling LoomExt::CoreFacts::FacterProvider and
    # now I've made a mess.... sighhhhh
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
      # TODO: Is this really necessary, or overly defensive? I can't think of a
      # good reason to keep it, but would like to know definitively.
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
