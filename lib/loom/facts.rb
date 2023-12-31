require_relative "facts/all"

module Loom
  module Facts
    class << self

      def fact_set(host_spec, shell, loom_config)
        FactSet.create_for_host host_spec, shell, loom_config
      end

    end
  end
end
