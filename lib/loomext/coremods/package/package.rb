require "forwardable"
require_relative "adapter"

module LoomExt::CoreMods
  class Package < Loom::Mods::Module

    UnsupportedPackageManager = Class.new Loom::Mods::ModActionError

    attr_reader :pkg_adapter

    register_mod :pkg

    def initialize(shell)
      super shell
      @pkg_adapter = install_adapter
    end

    def get(adapter)
      case adapter.to_sym
      when :dnf
        DnfAdapter.new shell
      when :rpm
        RpmAdapter.new shell
      when :apt
        AptAdapter.new shell
      when :dpkg
        DpkgAdapter.new shell
      when :gem
        GemAdapter.new shell
      else
        raise UnsupportedPackageManager, adapter
      end
    end
    alias_method :[], :get

    def install_adapter
      if shell.test :which, "dnf"
        DnfAdapter.new shell
      elsif shell.test :which, "rpm"
        RpmAdapter.new shell
      elsif shell.test :which, "apt"
        AptAdapter.new shell
      elsif shell.test :which, "dpkg"
        DpkgAdapter.new shell
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
