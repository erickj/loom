require 'loom/facts'

describe Loom::Facts::FactSet do

  let(:fact_set) { Loom::Facts::FactSet.new hostspec, facts }
  let(:hostspec) { Loom::HostSpec.new "dummy.host" }
  let(:facts) {{
      :fact_a => :a,
      :fact_b => [:other, :facts]
    }}

  subject { fact_set }

  let(:other_fact_set) { Loom::Facts::FactSet.new hostspec, other_facts }
  let(:other_facts) {{
      :fact_y => :y,
      :fact_z => :z,
    }}

  context Loom::Facts::EMPTY do

    subject { Loom::Facts::EMPTY }

    it "should equal Facts.is_empty?" do
      expect(Loom::Facts.is_empty? subject).to be true

      # sanity
      expect(Loom::Facts.is_empty?({})).to be false
      expect(Loom::Facts.is_empty?(fact_set)).to be false
    end
  end

  context :merge do
    it "merges with other fact sets" do
      new_facts = subject.merge other_fact_set
      expect(new_facts[:fact_a]).to be :a
      expect(new_facts[:fact_y]).to be :y
    end

    it "merges with other hashes" do
      new_facts = subject.merge :other_stuff => :in_a_hash
      expect(new_facts[:fact_a]).to be :a
      expect(new_facts[:other_stuff]).to be :in_a_hash
    end
  end

  context :[] do

    it "returns EMPTY for no result" do
      expect(fact_set[:invalid_key]).to be Loom::Facts::EMPTY
    end

    it "gets facts by name" do
      expect(fact_set[:fact_a]).to be :a
    end
  end
end
