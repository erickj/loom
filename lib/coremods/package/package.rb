require "forwardable"
require "loom/mods"
require_relative "adapter"

module Loom::CoreMods
  class Package < Loom::Mods::Module

    UnsupportedPackageManager = Class.new Loom::Mods::ModActionError

    attr_reader :pkg_adapter

    register_mod :pkg

    def initialize(shell)
      super shell
      @pkg_adapter = install_adapter
    end

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
      :update_cache, :upgrade
    end

    import_actions Package::Actions

  end
end
