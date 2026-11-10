# frozen_string_literal: true

RSpec.describe Hyrax::Pid do
  it "has a version number" do
    expect(Hyrax::Pid::VERSION).not_to be nil
  end

  describe ".configure" do
    after { described_class.instance_variable_set(:@configuration, nil) }

    it "yields the shared configuration" do
      described_class.configure { |config| config.data_cite.prefix = "10.5555" }
      expect(described_class.configuration.data_cite.prefix).to eq("10.5555")
    end
  end

  describe "default registrations" do
    it "registers :doi, resolving to a DataCite minter built from configuration" do
      described_class.configure do |config|
        config.data_cite.prefix = "10.5555"
        config.data_cite.username = "user"
        config.data_cite.password = "pass"
      end

      expect(Hyrax::Pid::Registry.minter_for(:doi)).to be_a(Hyrax::Pid::DataCite::Minter)
    end
  end
end
