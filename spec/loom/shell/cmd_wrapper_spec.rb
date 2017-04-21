require "loom/shell"
require "yaml"

describe Loom::Shell::CmdWrapper do

  def unescape_cmd(cmd)
    YAML.load(%Q(---\n"#{cmd.to_s}"\n))
  end

  context "examples" do
    it "escapes spaces" do
      cmd = Loom::Shell::CmdWrapper.new :printf, "print out this string"
      expect(%x{#{cmd}}).to eql "print out this string"
    end

    it "skips escaping symbols and frozen string" do
      cmd = Loom::Shell::CmdWrapper.new :"/bin/echo", :"\"yy\"", "\"xx\""
      expect(%x{#{cmd}}.strip).to eql "yy \"xx\""
    end
  end

  context ".new" do
    it "does not escape whitespace between joined commands parts" do
      cmd = Loom::Shell::CmdWrapper.new :echo, "-n", "\"all the rest\""
      expect(cmd.escape_cmd).to eql "echo -n \\\"all\\ the\\ rest\\\""
    end

    it "flattens cmd input" do
      cmd = Loom::Shell::CmdWrapper.new :somecmd, ["-f", "file.txt"], [:a, [:b]]
      expect(cmd.to_s).to eql "somecmd -f file.txt a b"
    end
  end

  context ".escape" do
    it "escapes CmdWrappers" do
      cmd = Loom::Shell::CmdWrapper.new '"hi"'
      expect(Loom::Shell::CmdWrapper.escape cmd).to eql cmd.to_s
    end

    it "escapes recursively" do
      content = 'I said "row row row your boat"'
      cmd_inner = 'echo "%s"' % Loom::Shell::CmdWrapper.escape(content)
      cmd_outer = '"%s"' % Loom::Shell::CmdWrapper.escape(cmd_inner)

      expected = '"echo\ \"I\\\\\ said\\\\\ ' +
                 '\\\\\"row\\\\\ row\\\\\ row\\\\\ your\\\\\ boat\\\\\"\""'

      printf_expected = 'echo\\ "I\ said\ "row\ row\ row\ your\ boat""'

      expect(cmd_outer).to eql expected
      expect(%x{printf #{cmd_outer}}.strip).to eql printf_expected
    end
  end

  context "#escape" do
    it "escapes strings with quotes" do
      cmd = Loom::Shell::CmdWrapper.new '"hi"'

      expected = '\"hi\"'
      expect(cmd.escape_cmd).to eql expected
      expect(%x{printf #{expected}}.strip).to eql unescape_cmd(cmd)
    end

    it "ignores strings without quotes" do
      cmd = Loom::Shell::CmdWrapper.new 'hi'

      expected = 'hi'
      expect(cmd.escape_cmd).to eql expected
      expect(%x{printf #{expected}}.strip).to eql unescape_cmd(cmd)
    end

    it "escapes nested quotes" do
      cmd = Loom::Shell::CmdWrapper.new 'echo "hi"'

      expected = 'echo\\ \"hi\"'
      expect(cmd.escape_cmd).to eql expected
      expect(%x{printf #{expected}}.strip).to eql unescape_cmd(cmd)
    end

    it "respects frozen? string" do
      cmd = Loom::Shell::CmdWrapper.new :echo, "\"^FROZEN^\"".freeze, :"^", "^"

      expected = 'echo "^FROZEN^" ^ \^'
      expect(cmd.escape_cmd).to eql expected
    end

    it "respects wrapped frozen? strings" do
      cmd_inner = Loom::Shell::CmdWrapper.new :echo, "\"^#FROZEN^\"".freeze
      cmd = Loom::Shell::CmdWrapper.wrap_cmd :sudo, cmd_inner

      expected = 'sudo echo "^#FROZEN^"'
      expect(cmd.escape_cmd).to eql expected
    end
  end

  # I don't want to think about this shit anymore. Don't touch this unless its
  # broken.
  context "#wrap" do
    it "preserves escaped CmdWrappers: depth 2" do
      cmd_which = Loom::Shell::CmdWrapper.new :which, :ls
      cmd_sh = Loom::Shell::CmdWrapper.new :"/bin/sh", "-c", should_quote: true

      composed_cmd = cmd_sh.wrap(cmd_sh.wrap(cmd_which)).to_s

      expected = "/bin/sh -c \"/bin/sh -c \\\"which ls\\\"\""

      expect(composed_cmd).to eql expected
      # Matches /bin/ls$ for portability, on fedora it's /usr/bin/ls
      expect(%x{#{composed_cmd}}.strip).to match /\/bin\/ls$/
    end

    it "preserves escaped CmdWrappers: depth N" do
      cmd_which = Loom::Shell::CmdWrapper.new :which, :ls
      cmd_sh = Loom::Shell::CmdWrapper.new :"/bin/sh", "-c", should_quote: true

      composed_cmd = cmd_sh.wrap(cmd_sh.wrap(cmd_sh.wrap(cmd_which))).to_s

      expected =
        "/bin/sh -c \"/bin/sh -c \\\"/bin/sh -c \\\\\\\"which ls\\\\\\\"\\\"\""

      expect(composed_cmd).to eql expected
      # Matches /bin/ls$ for portability, on fedora it's /usr/bin/ls
      expect(%x{#{composed_cmd}}.strip).to match /\/bin\/ls$/
    end
  end

  context Loom::Shell::CmdRedirect do

    let(:cmd_parts) { [:"/bin/ls"] }

    it "redirects stdout to file" do
      redirect = Loom::Shell::CmdRedirect.new "/my/file"
      cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

      expect(cmd.to_s).to eql "/bin/ls >/my/file"
    end

    it "redirects stderr to file" do
      redirect = Loom::Shell::CmdRedirect.new "/my/file", fd: 2
      cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

      expect(cmd.to_s).to eql "/bin/ls 2>/my/file"
    end

    it "appends stdout to file" do
      mode = Loom::Shell::CmdRedirect::Mode::APPEND

      redirect = Loom::Shell::CmdRedirect.new "/my/file", mode: mode
      cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

      expect(cmd.to_s).to eql "/bin/ls >>/my/file"
    end

    it "appends stderr to file" do
      mode = Loom::Shell::CmdRedirect::Mode::APPEND

      redirect = Loom::Shell::CmdRedirect.new "/my/file", fd: 2, mode: mode
      cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

      expect(cmd.to_s).to eql "/bin/ls 2>>/my/file"
    end

    it "redirects stderr to stdout" do
      redirect = Loom::Shell::CmdRedirect.new 1, fd: 2
      cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

      expect(cmd.to_s).to eql "/bin/ls 2>1"
    end

    it "redirects both stderr and stdout to file" do
      mode = Loom::Shell::CmdRedirect::Mode::OUTPUT_12

      redirect = Loom::Shell::CmdRedirect.new "/my/file", mode: mode
      cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

      expect(cmd.to_s).to eql "/bin/ls &>/my/file"
    end

    context "helper factories" do

      it "appends to stdout" do
        redirect = Loom::Shell::CmdRedirect.append_stdout "/my/file"
        cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirect

        expect(cmd.to_s).to eql "/bin/ls >>/my/file"
      end
    end

    context "multiple redirects" do
      it "redirects both stderr and stdout to file" do

        redirects = [
          Loom::Shell::CmdRedirect.new("/my/file"),
          Loom::Shell::CmdRedirect.new(1, fd: 2)
        ]
        cmd = Loom::Shell::CmdWrapper.new *cmd_parts, redirect: redirects

        expect(cmd.to_s).to eql "/bin/ls >/my/file 2>1"
      end
    end

    context "wrapped redirects" do
      it "does not escape redirects" do
        skip "fails - this is why I started implementing the harness see " +
          "`git show 1196d2ec2` for info"
        r = Loom::Shell::CmdRedirect.append_stdout "/my/file"

        cmd_inner = Loom::Shell::CmdWrapper.new :echo, :hello, redirect: r
        cmd = Loom::Shell::CmdWrapper.wrap_cmd :sudo, "-u", :root, cmd_inner

        expect(cmd.to_s).to eql "sudo -u root echo hello >>/my/file"
      end
    end
  end

  context Loom::Shell::CmdPipeline do

    let(:cmds) do
      [
        Loom::Shell::CmdWrapper.new(:find, ".", "-name", "*foo", "-print0"),
        Loom::Shell::CmdWrapper.new(:xargs, "-0", "-I-", "ls", "-")
      ]
    end

    it "pipes commands together" do
      pipeline = Loom::Shell::CmdPipeline.new cmds

      expected = "find . -name \\*foo -print0 | xargs -0 -I- ls -"
      expect(pipeline.to_s).to eql expected
    end

    it "accepts commands as pre-escaped strings" do
      pipeline = Loom::Shell::CmdPipeline.new ["I'm already escaped", "me too!"]

      expected = "I'm already escaped | me too!"
      expect(pipeline.to_s).to eql expected
    end
  end
end
