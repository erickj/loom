describe Loom::Resource do

  describe Loom::Resource::Script do
    describe "#path" do
      it "raises UnknownResourceError unless path exists" do
        expect { Loom::Resource::Script.path :foo }.to raise_error
      end

      it "returns paths to script resources" do
        expect(Loom::Resource::Script.path 'harness.sh').to match(
          /..\/scripts\/harness.sh$/)
      end
    end

    describe "#exists?" do
      it "returns false if the script doesn't exist" do
        expect(Loom::Resource::Script.exists? :foo).to be false
      end

      it "returns true if the script exists" do
        expect(Loom::Resource::Script.exists? 'harness.sh').to be true
      end
    end
  end
end
