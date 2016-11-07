require "loom/mods"

module Loom::CoreMods
  class Users < Loom::Mods::Module

    register_mod :users
    required_commands :useradd, :userdel, :getent

    def user_exists?(user)
      shell.test :getent, "passwd #{user}"
    end

    module Actions
      def add_user(user,
                   home_dir: nil,
                   login_shell: "/bin/bash",
                   uid: nil,
                   gid: nil,
                   groups: [],
                   is_system_user: nil)
        if user_exists? user
          Loom.log.warn "add_user skipping existing user => #{user}"
          return
        end

        flags = []
        flags << "--home-dir %s" % home_dir if home_dir
        flags << "--create-home" if home_dir
        flags << "--shell %s" % login_shell if login_shell
        flags << "--uid %s" % uid if uid
        flags << "--gid %s" % gid if gid
        flags << "--groups %s" % groups.join(" ") unless groups.empty?
        flags << "--system" if is_system_user

        shell.exec "useradd %s %s" % [flags.join(" "), user]
      end

      def add_system_user(user, **user_fields)
        if user_exists? user
          Loom.log.warn "add_system_user skipping existing user => #{user}"
          return
        end

        add_user user, is_system_user: true, login_shell: "/bin/false", **user_fields
      end

      def remove_user(user)
        unless user_exists? user
          Loom.log.warn "remove_user skipping non-existant user => #{user}"
          return
        end

        shell.exec "userdel -r %s" % user
      end
    end
  end

  Users.import_actions Users::Actions
end
