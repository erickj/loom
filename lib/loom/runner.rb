module Loom
  class Runner

    UnknownPattern = Class.new StandardError

    include Loom::DSL

    def initialize(loom_config, pattern_slugs=[])
      @pattern_slugs = pattern_slugs
      @pattern_loader = Loom::Pattern::Loader.configure loom_config
      @inventory_list = Loom::Inventory::InventoryList.active_inventory loom_config
    end

    def run(dry_run)
      if @pattern_slugs.empty?
        Loom.log.warn "no patterns given, there's no work to do"
        return
      end

      active_hosts = @inventory_list.hosts

      if active_hosts.empty?
        Loom.log.warn "no hosts in the active inventory"
        return
      end

      pattern_slugs = @pattern_slugs
      pattern_loader = @pattern_loader

      on_host active_hosts do |shell, mods, host|
        pattern_slugs.each do |pattern_slug|
          pattern_ref = pattern_loader[pattern_slug]
          raise UnknownPattern, pattern_slug unless pattern_ref

          pattern_description = "#{host.hostname} => #{pattern_slug}"
          if dry_run
            Loom.log.warn "dry run: #{pattern_description}"
          else
            bound_pattern_method = pattern_ref.bind Object.new
            Loom.log.info pattern_description
            bound_pattern_method.call shell, mods, host
          end

        end
      end
    end
  end
end
