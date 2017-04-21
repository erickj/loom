module LoomExt::CoreMods::VM
  class Virtualbox < Loom::Mods::Module

    DuplicateVMImport = Class.new Loom::ExecutionError
    UnknownVM = Class.new Loom::ExecutionError

    register_mod :vbox
    required_commands :vboxmanage

    module Actions
      def check_exists(vm)
        loom.test "vboxmanage showvminfo #{vm}".split
      end

      def check_running(vm)
        loom.test "vboxmanage list runningvms | grep \"#{vm}\"".split
      end

      def list
        loom << "vboxmanage list vms".split
      end

      def snapshot(vm, action: :take, snapshot_name: nil)
        raise UnknownVM, src_vm unless check_exists(vm)

        cmd = ["vboxmanage snapshot #{vm} #{action}"]
        cmd <<  snapshot_name if snapshot_name
        cmd = cmd.join " "

        loom << cmd.split
      end

      def import(ova_file, vm, disk, take_snapshot: true)
        raise DuplicateVMImport, vm if check_exists(vm)

        loom << "vboxmanage import #{ova_file} \
            --vsys 0 --vmname #{vm} \
            --vsys 0 --unit 12 --disk '#{disk}'"

        if take_snapshot
          snapshot vm, action: :take, snapshot_name: "#{vm}:import"
        end
      end

      def clone(src_vm, dst_vm, options: :link, snapshot: nil, take_snapshot: true)
        raise DuplicateVMImport, "VM already exists => #{dst_vm}" if check_exists(dst_vm)
        raise UnknownVM, src_vm unless check_exists(src_vm)

        cmd = ["vboxmanage clonevm #{src_vm}"]
        cmd << "--snapshot #{snapshot}" if snapshot
        cmd << "--options #{options}" if options
        cmd << "--name #{dst_vm}"
        cmd << "--register"
        cmd = cmd.join " "

        loom << cmd

        if take_snapshot
          snapshot dst_vm, action: :take, snapshot_name: "#{dst_vm}:clone"
        end
      end

      def up(vm)
        unless check_running(vm)
          loom << "vboxmanage startvm #{vm} --type headless"
        else
          Loom.log.warn "VM #{vm} already running, nothing to do"
        end
      end

      def down(vm)
        if check_running(vm)
          loom << "vboxmanage controlvm #{vm} acpipowerbutton"
        else
          Loom.log.warn "VM #{vm} not running, nothing to do"
        end
      end
    end

    import_actions Actions
  end
end
