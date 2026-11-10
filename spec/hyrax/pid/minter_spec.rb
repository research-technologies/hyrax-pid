# frozen_string_literal: true

RSpec.describe Hyrax::Pid::Minter do
  subject(:minter) { described_class.new }

  describe "#mint" do
    it "raises NotImplementedError" do
      expect { minter.mint(metadata: {}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#update" do
    it "raises NotImplementedError" do
      expect { minter.update(identifier: "x", metadata: {}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#find" do
    it "raises NotImplementedError" do
      expect { minter.find(identifier: "x") }.to raise_error(NotImplementedError)
    end
  end

  describe "#identifier_type" do
    it "raises NotImplementedError" do
      expect { minter.identifier_type }.to raise_error(NotImplementedError)
    end
  end
end
