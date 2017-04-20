require "loom/config"
require "loom/inventory"
require "tmpdir"
require "yaml"

describe Loom::Inventory do

  HOSTLIST = %w[host1 host2 host3]
  HOSTGROUPS = {
    :group1 => %w[g1host g2host],
    :duplicate_group => %w[host1]
  }

  INVENTORY_HOSTLIST = [
    'inv.host1',
    'inv.host2',
    :inventory_group => ['inv.group.host'],
    'string_group' => ['string.group.host']
  ]

  class TmpInventoryFile
    def self.transaction(search_paths_list, &block)
      Dir.mktmpdir do |dir|
        search_paths_list << dir

        File.open File.join(dir, "inventory.yml"), "w" do
          |f| f << INVENTORY_HOSTLIST.to_yaml
        end
        yield
      end
    end
  end

  CONFIG_DEFAULTS = {
    :loom_search_paths => []
  }

  let(:config_map) { {} }
  let(:config) do
    Loom::Config.configure do |c|
      CONFIG_DEFAULTS.merge(config_map).each { |k,v| c[k] = v }
    end
  end

  context "methods" do

    subject { Loom::Inventory::InventoryList.new hostlist, hostgroups }
    let(:hostlist) { HOSTLIST }
    let(:hostgroups) { {} }

    it "#hosts should parse hostnames" do
      expect(subject.hosts.first).to be_a Loom::HostSpec
      expect(subject.hosts.size).to be 3
    end

    it "lists #hostnames" do
      expect(subject.hostnames).to eql %w[host1 host2 host3]
    end

    context "with groups" do

      let(:hostgroups) { HOSTGROUPS }

      context "#hostnames" do
        it "#hostnames includes hostnames from the group" do
          expect(subject.hostnames).to include("g1host")
        end

        it "only lists unique hosts" do
          expect(subject.hostnames.size).to be 5
        end
      end

      it "lists #group_names" do
        expect(subject.group_names).to eq [:group1, :duplicate_group]
      end
    end
  end

  context "#total_inventory" do

    subject { Loom::Inventory::InventoryList.total_inventory config }

    context "with explicit hosts configured" do

      let(:config_map) { {:inventory_hosts => %w[confighost1 confighost2]} }

      it "gets hosts from config" do
        expect(subject.hostnames).to eq %w[confighost1 confighost2]
      end
    end

    context "with inventory files" do

      # To be passed into the TmpInventoryFile.transaction by :around
      let(:config_map) { {:loom_search_paths => []} }

      around(:example) do |example|
        TmpInventoryFile.transaction config_map[:loom_search_paths], &example
      end

      it "finds hosts in the tmp config" do
        expected = %w[inv.host1 inv.host2 inv.group.host string.group.host]
        expect(subject.hostnames).to match_array expected
      end

    end
  end

  context "#active_inventory" do

    subject { Loom::Inventory::InventoryList.active_inventory config }

    context "with inventory file" do

      around(:example) do |example|
        TmpInventoryFile.transaction config_map[:loom_search_paths], &example
      end

      context "with explicit hosts" do

        # To be passed into the TmpInventoryFile.transaction by :around
        let(:config_map) do
          {:inventory_hosts => HOSTLIST, :loom_search_paths => []}
        end

        it "gets only explicit hosts from config" do
          expect(subject.hostnames).to eq HOSTLIST
        end
      end

      context "with explicit groups" do

        # To be passed into the TmpInventoryFile.transaction by :around
        let(:config_map) do
          {:inventory_groups => [:inventory_group, :string_group],
           :loom_search_paths => []}
        end

        it "gets only explicit hosts from config" do
          expect(subject.hostnames).to match_array %w[inv.group.host string.group.host]
        end

      end
    end
  end
end
