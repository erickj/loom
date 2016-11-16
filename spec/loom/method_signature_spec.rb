require "loom/method_signature"

describe Loom::MethodSignature do

  module MethodModule
    def one_req_arg(req); end
    def two_req_args(req1, req2); end

    def opt_arg(opt=nil); end
    def two_opt_args(opt1=1, opt2=nil); end

    def rest_args(*rest); end
    def req_and_rest_args(req, *rest); end
    def req_and_opt_and_rest_args(req, opt=nil, *rest); end

    def one_keyreq_arg(keyreq:); end
    def two_keyreq_args(keyreq1:, keyreq2:); end

    def one_key_arg(key: 1); end
    def two_key_args(key1: 1, key2: nil); end

    def keyrest_arg(**keyrest); end
    def key_and_keyrest_arg(keyreq:, key: 2, **keyrest); end

    def block_arg(&block); end

    def all_args(req, opt=1, *rest, keyreq:, key: 2, **keyrest, &block); end
    def no_args; end

    class << self
      def [](method_name)
        MethodModule.instance_method method_name
      end
    end
  end

  context Loom::MethodSignature do

    context "#one_req_arg" do
      subject { Loom::MethodSignature.new MethodModule[:one_req_arg] }

      it "has the right signature" do
        expect(subject.req_args.size).to be 1
      end

      it "implements has_xyz_args?" do
        expect(subject.has_req_args?).to be true
        expect(subject.has_opt_args?).to be false
        expect(subject.has_rest_args?).to be false
      end
    end

    context "#one_req_arg" do
      subject { Loom::MethodSignature.new MethodModule[:one_keyreq_arg] }

      it "has the right signature" do
        expect(subject.keyreq_args.size).to be 1
      end

      it "implements has_xyz_args?" do
        expect(subject.has_keyreq_args?).to be true
        expect(subject.has_key_args?).to be false
        expect(subject.has_keyrest_args?).to be false
      end
    end

    context "#keyrest_arg" do
      subject { Loom::MethodSignature.new MethodModule[:keyrest_arg] }

      it "has the right signature" do
        expect(subject.keyrest_args.size).to be 1
      end

      it "implements has_xyz_args?" do
        expect(subject.has_keyreq_args?).to be false
        expect(subject.has_key_args?).to be false
        expect(subject.has_keyrest_args?).to be true
      end
    end

    context "#two_key_args" do
      subject { Loom::MethodSignature.new MethodModule[:two_key_args] }

      it "has the right signature" do
        expect(subject.req_args.size).to be 0
        expect(subject.opt_args.size).to be 0
        expect(subject.rest_args.size).to be 0

        expect(subject.keyreq_args.size).to be 0
        expect(subject.key_args.size).to be 2
        expect(subject.keyrest_args.size).to be 0

        expect(subject.block_args.size).to be 0
      end
    end

    context "#all_args" do
      subject { Loom::MethodSignature.new MethodModule[:all_args] }

      it "has the right signature" do
        expect(subject.req_args.size).to be 1
        expect(subject.opt_args.size).to be 1
        expect(subject.rest_args.size).to be 1

        expect(subject.keyreq_args.size).to be 1
        expect(subject.key_args.size).to be 1
        expect(subject.keyrest_args.size).to be 1

        expect(subject.block_args.size).to be 1
      end

      it "implements has_xyz_args?" do
        expect(subject.has_req_args?).to be true
        expect(subject.has_opt_args?).to be true
        expect(subject.has_rest_args?).to be true

        expect(subject.has_keyreq_args?).to be true
        expect(subject.has_key_args?).to be true
        expect(subject.has_keyrest_args?).to be true

        expect(subject.has_block_args?).to be true
      end
    end

    context "#no_args" do
      subject { Loom::MethodSignature.new MethodModule[:no_args] }

      it "has the right signature" do
        expect(subject.req_args.size).to be 0
        expect(subject.opt_args.size).to be 0
        expect(subject.rest_args.size).to be 0

        expect(subject.keyreq_args.size).to be 0
        expect(subject.key_args.size).to be 0
        expect(subject.keyrest_args.size).to be 0
        expect(subject.block_args.size).to be 0
      end

      it "implements has_xyz_args?" do
        expect(subject.has_req_args?).to be false
        expect(subject.has_opt_args?).to be false
        expect(subject.has_rest_args?).to be false

        expect(subject.has_keyreq_args?).to be false
        expect(subject.has_key_args?).to be false
        expect(subject.has_keyrest_args?).to be false

        expect(subject.has_block_args?).to be false
      end
    end
  end

  context Loom::MethodSignature::MatchSpec do

    context 'with required argument matching' do

      subject { Loom::MethodSignature::MatchSpec.builder.req_args(1).build }
      let(:passing_methods) { [:one_req_arg, :rest] }

      MethodModule.instance_methods.each do |m|
        it "checks ##{m} for matches" do
          v = passing_methods.include? m
          expect(subject.match?(MethodModule[m])).to be v
        end
      end
    end

    context 'with optional argument matching' do

      subject { Loom::MethodSignature::MatchSpec.builder.opt_args(1).build }
      let(:passing_methods) { [:opt_arg, :rest] }

      MethodModule.instance_methods.each do |m|
        it "checks ##{m} for matches" do
          v = passing_methods.include? m
          expect(subject.match?(MethodModule[m])).to be v
        end
      end
    end

    context 'with required keyword argument matching' do

      subject { Loom::MethodSignature::MatchSpec.builder.keyreq_args(1).build }
      let(:passing_methods) { [:one_keyreq_arg] }

      MethodModule.instance_methods.each do |m|
        it "checks ##{m} for matches" do
          v = passing_methods.include? m
          expect(subject.match?(MethodModule[m])).to be v
        end
      end
    end

    context 'with optional keyword argument matching' do

      subject { Loom::MethodSignature::MatchSpec.builder.key_args(1).build }
      let(:passing_methods) { [:one_key_arg] }

      MethodModule.instance_methods.each do |m|
        it "checks ##{m} for matches" do
          v = passing_methods.include? m
          expect(subject.match?(MethodModule[m])).to be v
        end
      end
    end

    context 'with a pattern signature' do

      subject do
        Loom::MethodSignature::MatchSpec.builder
          .req_args(2)
          .has_rest_args(nil)
          .has_keyrest_args(nil)
          .has_block(nil)
          .build
      end

      let(:valid) { lambda do |loom, config| end }
      let(:valid2) { lambda do |loom, config, *args| end }
      let(:valid3) { lambda do |*args| end }
      let(:invalid) { lambda do |loom, config, other| end }

      it "checks :valid passes for well formatted pattern" do
        expect(subject.match?(valid)).to be true
      end

      it "checks :valid2 passes for well formatted pattern" do
        expect(subject.match?(valid2)).to be true
      end

      it "checks :valid2 passes for well formatted pattern" do
        expect(subject.match?(valid3)).to be true
      end

      it "checks :invalid fails for badly formatted pattern" do
        expect(subject.match?(invalid)).to be false
      end

    end

    context 'with a mod signature' do

      subject do
        Loom::MethodSignature::MatchSpec.builder
          .req_args(2)
          .has_rest_args(nil)
          .has_keyrest_args(true)
          .has_block(nil)
          .build
      end

      let(:valid) { lambda do |loom, config, *args, **rest| end }
      let(:valid2) { lambda do |loom, config, **rest| end }
      let(:valid3) { lambda do |loom, config, foo:, bar: nil| end }
      let(:invalid) { lambda do |loom, config, foo, bar| end }

      it "checks :valid passes for well formatted pattern" do
        expect(subject.match?(valid)).to be true
      end

      it "checks :valid2 passes for well formatted pattern" do
        expect(subject.match?(valid2)).to be true
      end

      it "checks :valid3 passes for well formatted pattern" do
        expect(subject.match?(valid3)).to be true
      end

      it "checks :invalid fails for badly formatted pattern" do
        expect(subject.match?(invalid)).to be false
      end

    end
  end
end
