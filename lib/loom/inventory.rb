require 'yaml'

module Loom
  module Inventory

    InvalidHostEntry = Class.new StandardError
    InventoryFileEntryError = Class.new StandardError

    INVENTORY_FILE_NAMES = [
      "inventory.yml",
      "inventory.yaml"
    ]

    class InventoryList

      class << self
        def total_inventory(loom_config)
          inventory_fileset = InventoryFileSet.new loom_config.inventory_roots
          InventoryList.new inventory_fileset.hostlist, inventory_fileset.hostgroups
        end

        ##
        # The list of hosts to apply patterns to
        def active_inventory(loom_config)
          explicit_hostlist = loom_config.inventory_hosts
          InventoryList.new explicit_hostlist
        end
      end

      attr_reader :hosts

      def initialize(hostlist, hostgroups={})
        @hosts = parse_hosts(hostlist).uniq { |h| h.hostname }
        @hostgroups = hostgroups
      end

      def parse_hosts(list)
        list.map do |hoststring|
          raise InvalidHostEntry, hoststring.class.name unless hoststring.is_a? String
          HostSpec.new hoststring
        end
      end

      def hostnames
        @hosts.map { |h| h.hostname }
      end

      def group_names
        @hostgroups.keys
      end
    end

    private
    class InventoryFileSet
      def initialize(roots)
        @roots = roots

        inventory_file_paths = @roots.map do |root|
          search_globs = INVENTORY_FILE_NAMES.map do |name|
            File.join root, "**", name
          end
          Dir.glob search_globs
        end.flatten.map { |p| File.realpath p}

        @raw_inventories = inventory_file_paths.map do |path|
          Loom.log.debug "loading inventory file #{path}"
          YAML.load_file path
        end
      end

      def hostgroups
        @raw_inventories.reduce({}) do |map, i|
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
        @raw_inventories.map do |i|
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
