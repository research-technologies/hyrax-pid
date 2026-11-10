# frozen_string_literal: true

RSpec.describe Hyrax::Pid::Identifier do
  subject(:identifier) do
    described_class.new(value: "10.1234/abcd", type: :doi, state: :findable, raw: {status: 200})
  end

  it "exposes value, type, state, and raw" do
    expect(identifier.value).to eq("10.1234/abcd")
    expect(identifier.type).to eq(:doi)
    expect(identifier.state).to eq(:findable)
    expect(identifier.raw).to eq({status: 200})
  end

  it "defaults state and raw to nil" do
    identifier = described_class.new(value: "10.1234/abcd", type: :doi)
    expect(identifier.state).to be_nil
    expect(identifier.raw).to be_nil
  end

  describe "#to_s" do
    it "returns the value" do
      expect(identifier.to_s).to eq("10.1234/abcd")
    end
  end
end
