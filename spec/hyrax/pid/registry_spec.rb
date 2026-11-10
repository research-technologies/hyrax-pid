# frozen_string_literal: true

RSpec.describe Hyrax::Pid::Registry do
  # Snapshot/restore rather than .clear, so this doesn't wipe out the
  # gem's own default registrations (e.g. :doi) for specs that run after.
  around do |example|
    original = described_class.send(:registrations).dup
    described_class.clear
    example.run
    described_class.clear
    original.each { |key, minter| described_class.register(key, minter) }
  end

  let(:fake_minter_class) do
    Class.new(Hyrax::Pid::Minter) do
      def identifier_type
        :doi
      end
    end
  end

  describe ".register and .minter_for" do
    it "instantiates a registered class" do
      described_class.register(:doi, fake_minter_class)
      expect(described_class.minter_for(:doi)).to be_a(fake_minter_class)
    end

    it "calls a registered callable" do
      instance = fake_minter_class.new
      described_class.register(:doi, -> { instance })
      expect(described_class.minter_for(:doi)).to eq(instance)
    end

    it "returns a registered instance as-is" do
      instance = fake_minter_class.new
      described_class.register(:doi, instance)
      expect(described_class.minter_for(:doi)).to eq(instance)
    end

    it "normalizes string keys to symbols" do
      described_class.register("doi", fake_minter_class)
      expect(described_class.minter_for(:doi)).to be_a(fake_minter_class)
    end

    it "raises UnregisteredError for an unknown key" do
      expect { described_class.minter_for(:raid) }.to raise_error(Hyrax::Pid::Registry::UnregisteredError)
    end
  end

  describe ".registered_keys" do
    it "lists registered keys as symbols" do
      described_class.register(:doi, fake_minter_class)
      described_class.register(:raid, fake_minter_class)
      expect(described_class.registered_keys).to contain_exactly(:doi, :raid)
    end
  end

  describe ".unregister" do
    it "removes a registration" do
      described_class.register(:doi, fake_minter_class)
      described_class.unregister(:doi)
      expect(described_class.registered_keys).to be_empty
    end
  end
end
