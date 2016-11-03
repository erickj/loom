require 'yaml'

module Loom
  module Inventory

    InvalidHostEntry = Class.new StandardError
    InventoryFileEntryError = Class.new StandardError

    INVENTORY_FILE_GLOB = "inventory.*"

    class << self
      def total_inventory
        inventory_fileset = InventoryFileSet.new Loom.config.inventory_roots
        InventoryList.new hostlistinventory_fileset.hostlist, inventory_fileset.hostgroups
      end

      def active_inventory
        explicit_hostlist = Loom.config.loom_hosts
        InventoryList.new explicit_hostlist
      end
    end

    class InventoryList

      attr_reader :hosts

      def initialize(hostlist, hostgroups={})
        @hosts = parse_hosts(hostlist).uniq { |h| h.hostname }
        @hostgroups = hostgroups
      end

      def parse_hosts(list)
        list.map do |hoststring|
          raise InvalidHostEntry, hoststring.class.name unless hoststring.is_a? String
          host = parse hoststring
        end
      end

      def parse(hoststring)
        SSHKit::Host.new hoststring
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
          search_glob = File.join root, "**", INVENTORY_FILE_GLOB
          Loom.log.debug { "searching inventory glob: #{search_glob}" }

          Dir.glob search_glob
        end.flatten.map { |p| File.realpath p}

        @raw_inventories = inventory_file_paths.map do |path|
          Loom.log.info "loading inventory file #{path}"
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
