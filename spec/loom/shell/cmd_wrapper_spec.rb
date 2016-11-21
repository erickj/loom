require "loom/shell"

describe Loom::Shell::CmdWrapper do

  context ".new" do
    it "does not escape whitespace between joined commands parts" do
      cmd = Loom::Shell::CmdWrapper.new :echo, "-n", "\"all the rest\""
      expect(cmd.escape_cmd).to eql "echo -n \\\"all\\ the\\ rest\\\""
    end
  end

  context "#escape" do

    it "escapes strings with quotes" do
      cmd = '"hi"'
      expected = '\"hi\"'
      expect(Loom::Shell::CmdWrapper.escape cmd).to eql expected
      expect(%x{printf #{expected}}.strip).to eql cmd
    end

    it "ignores strings without quotes" do
      cmd = 'hi'
      expected = 'hi'
      expect(Loom::Shell::CmdWrapper.escape cmd).to eql expected
      expect(%x{printf #{expected}}.strip).to eql cmd
    end

    it "escapes nested quotes" do
      cmd = 'echo "hi"'
      expected = 'echo\\ \"hi\"'

      expect(Loom::Shell::CmdWrapper.escape cmd).to eql expected
      expect(%x{printf #{expected}}.strip).to eql cmd
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

  context "#wrap" do
    it "preserves escaped CmdWrappers" do
      cmd_which = Loom::Shell::CmdWrapper.new :which, :ls
      cmd_sh = Loom::Shell::CmdWrapper.new :"/bin/sh", "-c", should_quote: true

      composed_cmd = cmd_sh.wrap(cmd_sh.wrap(cmd_which)).to_s

      expected = "/bin/sh -c \"/bin/sh -c \\\"which ls\\\"\""
      expect(composed_cmd).to eql expected
      expect(%x{#{composed_cmd}}.strip).to eql "/usr/bin/ls"
    end
  end
end
