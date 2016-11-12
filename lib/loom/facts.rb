require_relative "facts/all"

module Loom
  module Facts
    class << self

      def fact_providers(loom_config)
        FactFileProvider.create_providers(loom_config)
      end

      def fact_set(shell, host_spec, fact_providers)
        FactSet.create_for_host shell, host_spec, fact_providers
      end

    end
  end
end
