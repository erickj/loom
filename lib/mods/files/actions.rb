module Loom::Mods
  module Files
    module Actions

      module Core
        extend Loom::Module::ModBuilder

        action :chown do |_, mods, user, group = nil, *paths|
          group_arg = group && ":" + group

          for_paths *paths do |p|
            _.chown [user, group_arg].compact.join, p
          end
        end

        action :ls do |_, mods, *paths|
          for_paths *paths, :action => :ls
        end

        action :touch do |_, mods, *paths|
          for_paths *paths, :action => :touch
        end

        action :mkdir do |_, mods, *paths, flags: nil, **opts|
          for_paths *paths, :action => :mkdir, :flags => flags
        end

        action :stat do |_, mods, *paths|
          for_paths *paths, :action => :stat
        end

        action :append do |_, mods, path, text|
          _.verify "[ -f #{path} ]"
          _.echo "\"#{text}\" >> #{path}"
        end

        action :write do |_, mods, path, text|
          _.verify "[ ! -f \"#{path}\" ]"
          write! path, text
        end

        action :write! do |_, mods, path, text|
          _.echo "\"#{text}\" > #{path}"
        end
        alias_method :overwrite, :write!
      end

      module Dir
        extend Loom::Module::ModBuilder

        action :cd do |_, mods, *paths, &block|
          cwd = _.pwd
          puts "pwd is: #{cwd}"

          for_paths *paths do |p|
            _.cd p
            block.call if block
            _.cd cwd
          end
        end
      end

      module Rsync
        extend Loom::Module::ModBuilder

        action :up do |_, mods, *args|
          puts "sync up #{args}"
        end

        action :down do |_, mods, *args|
          puts "sync down #{args}"
        end
      end
    end
  end
end
