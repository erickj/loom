module Loom::Pattern
  class PatternReference

    attr_reader :slug, :source_file

    def initialize(slug, unbound_method, original_module_name, source_file)
      @slug = slug
      @unbound_method = unbound_method
      @original_module_name = original_module_name
      @source_file = source_file
    end

    def call(*args, &block)
      begin
        binding_context.apply_pattern *args, &block
      rescue
        Loom.log.error "error executing pattern => #{original_method_name}\n\t" + $!.message
        raise
      end
    end

    private
    def original_method_name
      "%s+%s+" % [@original_module_name, @slug.split(":").last]
    end

    def binding_context
      PatternBinder.new @unbound_method
    end

    ##
    # A small class to bind the unbound_method to and provide context
    # in the case of errors.
    class PatternBinder
      def initialize(unbound_method)
        @bound_method = unbound_method.bind self
      end

      def apply_pattern(*args, &block)
        @bound_method.call *args, &block
      end
    end

  end
end
