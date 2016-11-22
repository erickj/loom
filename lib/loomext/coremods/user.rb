module LoomExt::CoreMods
  class User < Loom::Mods::Module

    SudoersDNoExistError = Class.new Loom::Mods::ModActionError
    SudoersDNotIncluded = Class.new Loom::Mods::ModActionError

    register_mod :user
    required_commands :useradd, :userdel, :getent

    SUDOERS_FILE = "/etc/sudoers"
    SUDOERS_DIR = "/etc/sudoers.d"
    LOOM_SUDOERS_FILE = SUDOERS_DIR + "/90-loom-sudoers"

    def user_exists?(user)
      shell.test :getent, :passwd, user
    end

    def includes_sudoers?
      shell.test :grep, %Q[-e "^#includedir #{SUDOERS_DIR}$" #{SUDOERS_FILE}]
    end

    def sudoersd_exists?
      shell.test :test, %Q[-d #{SUDOERS_DIR}]
    end

    def has_sudoer_conf?(conf)
      shell.test :grep, %Q[-e "^#{conf}$" #{LOOM_SUDOERS_FILE}]
    end

    module Actions
      def add(user,
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
        flags << ["--home-dir", home_dir] if home_dir
        flags << ["--create-home"] if home_dir
        flags << ["--shell", login_shell] if login_shell
        flags << ["--uid", uid] if uid
        flags << ["--gid", gid] if gid
        flags << ["--groups", groups] unless groups.empty?
        flags << "--system" if is_system_user

        loom.exec :useradd, flags, user
      end

      def add_system_user(user, **user_fields)
        if user_exists? user
          Loom.log.warn "add_system_user skipping existing user => #{user}"
          return
        end

        add user, is_system_user: true, login_shell: "/bin/false", **user_fields
      end

      def remove(user)
        unless user_exists? user
          Loom.log.warn "remove_user skipping non-existant user => #{user}"
          return
        end

        loom.exec :userdel, "-r", user
      end

      def make_sudoer(user, sudoer_conf: nil)
        raise SudoersDNotIncluded unless includes_sudoers?
        raise SudoersDNoExistError unless sudoersd_exists?

        sudoer_conf ||= "#{user} ALL=(ALL) NOPASSWD:ALL"
        if has_sudoer_conf? sudoer_conf
          Loom.log.warn "make_sudoer skipping conf #{sudoer_conf} => conf already exists"
          return
        end

        loom.exec :echo, %Q["#{sudoer_conf}" >> #{LOOM_SUDOERS_FILE}]
        loom.exec :chmod, 0440, LOOM_SUDOERS_FILE
      end
    end
  end

  User.import_actions User::Actions
end
