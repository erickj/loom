module Loom::Mods
  class ActionProxy

    def initialize(mod)
      @mod = mod
      @nested_action_proxies = {}
    end

    def proxy_for_namespace(ns=nil)
      ns.nil? ? self : @nested_action_proxies[ns]
    end

    private

    class << self      
      def new_action_map
        ActionMap.new
      end

      def subclass_for_action_map(action_map)
        sub_class = Class.new ActionProxy
        sub_class.install_action_map action_map
        sub_class
      end

      def install_action_map(action_map)
        install_root_actions action_map
        install_namespace_action_proxies action_map
      end

      def install_root_actions(action_map)
        action_map.action_tuples.each do |tuple|
          public_action_name = tuple[0]
          bound_action_name = tuple[1]

          define_method public_action_name do |*args, &block|
            @mod.send bound_action_name, *args, &block
          end
          puts "defined action proxy action: #{public_action_name} => #{bound_action_name}"
        end
      end

      ##
      # This gets a bit tricky
      def install_namespace_action_proxies(action_map)
        action_map.ns_actionmaps.each do |ns, ns_action_map|
          @nested_action_proxy_klasses ||= {}
          @nested_action_proxy_klasses[self.hash] ||= {}
          @nested_action_proxy_klasses[self.hash][ns] ||=
            ActionProxy.subclass_for_action_map ns_action_map
          action_proxy_klass = @nested_action_proxy_klasses[self.hash][ns]

          define_method ns do
            @nested_action_proxies[ns] ||= action_proxy_klass.new @mod
          end
          puts "defined action proxy ns: #{ns}"
        end
      end

    end

    class ActionMap

      attr_reader :action_tuples, :ns_actionmaps

      def initialize
        @action_tuples = []
        @ns_actionmaps = {}
      end

      def add_action(action_name, bound_method_name, namespace=nil)
        if namespace.nil?
          tuple = [action_name, bound_method_name]
          @action_tuples << tuple unless namespace 
        else
          # Adds an action name to a nested ActionMap
          add_namespace(namespace).add_action action_name, bound_method_name
        end
      end

      private
      def add_namespace(ns)
        @ns_actionmaps[ns] ||= ActionMap.new
      end
    end
  end
end
