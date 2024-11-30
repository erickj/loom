require 'loom/host_spec'

describe Loom::HostSpec do

  subject { Loom::HostSpec.new host_string }

  context "local strings" do

    context "with no user/nor port" do
      let(:host_string) { "localhost" }

      it "parses localhost configurations" do
        expect(subject.is_localhost?).to be true
        expect(subject.is_remote?).to be false
      end

      it "has been parsed" do
        expect(subject.hostname).to eq "localhost"
        expect(subject.user).to be nil
        expect(subject.port).to be nil
      end
    end

    context "with a user" do
      let(:host_string) { "ej@localhost" }

      it "parses configurations as remote" do
        expect(subject.is_localhost?).to be false
        expect(subject.is_remote?).to be true
      end

      it "has been parsed" do
        expect(subject.hostname).to eq "localhost"
        expect(subject.user).to eq "ej"
        expect(subject.port).to be nil
      end
    end

    context "with a port" do
      let(:host_string) { "localhost:22" }

      it "parses configurations as remote" do
        expect(subject.is_localhost?).to be false
        expect(subject.is_remote?).to be true
      end

      it "has been parsed" do
        expect(subject.hostname).to eq "localhost"
        expect(subject.user).to be nil
        expect(subject.port).to eq 22
      end
    end

  end

  context "remote strings" do

    let(:host_string) { "erick@remote.machine:27" }

    it "parses user@localhost configurations as remote" do
      expect(subject.is_localhost?).to be false
      expect(subject.is_remote?).to be true
    end

    it "has been parsed" do
      expect(subject.user).to eq "erick"
      expect(subject.hostname).to eq "remote.machine"
      expect(subject.port).to eq 27
    end
  end

  context "ipv4 addresses" do
    let(:host_string) { "erick@192.168.1.100:27" }

    it "parses user@localhost configurations as remote" do
      expect(subject.is_localhost?).to be false
      expect(subject.is_remote?).to be true
    end

    it "has been parsed" do
      expect(subject.user).to eq "erick"
      expect(subject.hostname).to eq "192.168.1.100"
      expect(subject.port).to eq 27
    end
  end

  context "ipv6 addresses" do
    let(:host_string) { "[2a02:120b:2c28:5920:6257:18ff:febf:13c8]:22" }

    it "parses user@localhost configurations as remote" do
      expect(subject.is_localhost?).to be false
      expect(subject.is_remote?).to be true
    end

    it "has been parsed" do
      expect(subject.hostname).to eq "2a02:120b:2c28:5920:6257:18ff:febf:13c8"
      expect(subject.user).to be nil
      expect(subject.port).to eq 22
    end
  end
end
