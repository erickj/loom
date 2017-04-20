module Loom
  module Resource

    UnknownResourceError = Class.new Loom::LoomError

    class Script

      # @param name [String|Symbol]
      def self.path(name)
        raise UnknownResourceError, name unless exists?(name)
        path_internal(name)
      end

      def self.exists?(name)
        File.exists?(path_internal(name))
      end

      private
      def self.path_internal(name)
        name = name.to_s
        File.join(
          File.dirname(File.expand_path(__FILE__)), '../../scripts', name)
      end
    end

    HARNESS = Script.path "harness.sh"
  end
end
