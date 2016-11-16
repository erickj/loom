require "forwardable"
require_relative "adapter"

module LoomExt::CoreMods
  class Package < Loom::Mods::Module

    UnsupportedPackageManager = Class.new Loom::Mods::ModActionError

    attr_reader :pkg_adapter

    register_mod :pkg

    def init_action
      @pkg_adapter = default_adapter
    end

    def get(adapter)
      case adapter.to_sym
      when :dnf
        DnfAdapter.new loom
      when :rpm
        RpmAdapter.new loom
      when :apt
        AptAdapter.new loom
      when :dpkg
        DpkgAdapter.new loom
      when :gem
        GemAdapter.new loom
      else
        raise UnsupportedPackageManager, adapter
      end
    end
    alias_method :[], :get

    def default_adapter
      if loom.test :which, "dnf"
        DnfAdapter.new loom
      elsif loom.test :which, "rpm"
        RpmAdapter.new loom
      elsif loom.test :which, "apt"
        AptAdapter.new loom
      elsif loom.test :which, "dpkg"
        DpkgAdapter.new loom
      else
        raise UnsupportedPackageManager
      end
    end

    module Actions
      extend Forwardable
      def_delegators :@pkg_adapter, :installed?, :install, :uninstall,
      :update_cache, :upgrade, :ensure_installed

      def [](*args)
        get(*args)
      end
    end

    import_actions Package::Actions

  end
end
