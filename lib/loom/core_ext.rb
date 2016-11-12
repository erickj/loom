module Loom
  module CoreExt
    refine String do
      def underscore
        uncamelify = self.gsub /[a-z\W][A-Z]/ do |m|
          m.gsub /(^.)/, '\1_' 
        end
        uncamelify.downcase.gsub(/[^a-z0-9]+/, '_')
      end

      def demodulize
        self.split('::').last
      end
    end

    module ModuleExt
      ##
      # A method like :attr_accessor, except the setter and getter
      # methods are combined into one. It acts as a setter if an
      # argument is passed, and always returns the currnet value.
      def loom_accessor(*names)
        names.each do |name|
          instance_variable_set "@#{name}", nil

          define_method name do |*args|
            raise 'expected 0..1 arguments' if args.size > 1
            instance_variable_set("@#{name}", args.first) if args.size > 0
            instance_variable_get "@#{name}"
          end
        end
      end
    end

    ::Module.include ModuleExt

  end
end
