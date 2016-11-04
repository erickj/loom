require 'yaml'

module Loom
  module Inventory

    InvalidHostEntry = Class.new Loom::LoomError
    InventoryFileEntryError = Class.new Loom::LoomError

    INVENTORY_FILE_NAMES = [
      "inventory.yml",
      "inventory.yaml"
    ]

    class InventoryList

      class << self
        def total_inventory(loom_config)
          fileset = InventoryFileSet.new inventory_files(loom_config)
          config_hostlist = loom_config.inventory_hosts
          hostlist = fileset.hostlist + config_hostlist
          InventoryList.new hostlist, fileset.hostgroup_map
        end

        ##
        # The list of hosts to apply patterns to
        def active_inventory(loom_config)
          return total_inventory loom_config if loom_config.inventory_all_hosts

          fileset = InventoryFileSet.new inventory_files(loom_config)
          groups = loom_config.inventory_groups.map(&:to_sym).reduce({}) do |map, group|
            Loom.log.debug2(self) { "looking for group => #{group}" }
            map[group] = fileset.hostgroup_map[group] if fileset.hostgroup_map.key? group
            map
          end
          Loom.log.debug1(self) { "groups map => #{groups}" }

          InventoryList.new loom_config.inventory_hosts, groups
        end

        private
        def inventory_files(loom_config)
          loom_config.files.find INVENTORY_FILE_NAMES
        end
      end

      attr_reader :hosts

      def initialize(hostlist, hostgroup_map={})
        @hostgroup_map = hostgroup_map

        all_hosts = hostgroup_map.values.flatten + hostlist
        @hosts = parse_hosts(all_hosts).uniq { |h| h.hostname }
        @disabled_hosts = {}
      end

      def disable(hostname)
        @disabled_hosts[hostname] = true
      end

      def disabled?(hostname)
        !!@disabled_hosts[hostname]
      end

      def hostnames
        @hosts.map { |h| h.hostname }
      end

      def group_names
        @hostgroup_map.keys
      end

      private
      def parse_hosts(list)
        list.map do |hoststring|
          raise InvalidHostEntry, hoststring.class.name unless hoststring.is_a? String
          HostSpec.new hoststring
        end
      end
    end

    private
    class InventoryFileSet
      def initialize(inventory_files)
        @hostgroup_map = nil
        @hostlist = nil

        @raw_inventories = inventory_files.map do |path|
          Loom.log.debug "loading inventory file #{path}"
          YAML.load_file path
        end
      end

      def hostgroup_map
        @hostgroup_map ||= @raw_inventories.reduce({}) do |map, i|
          i.each do |entry|
            if entry.is_a? Hash
              Loom.log.debug "merging groups in #{entry}"
              map.merge! entry
            end
          end
          map
        end
      end

      def hostlist
        @hostlist ||= @raw_inventories.map do |i|
          i.map do |entry|
            case entry
            when String
              entry
            when Hash
              entry.values
            else
              raise InventoryFileEntryError, "unexpected entry #{entry}"
            end
          end
        end.flatten
      end
    end
  end
end
