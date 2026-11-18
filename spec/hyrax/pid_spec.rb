# frozen_string_literal: true

RSpec.describe Hyrax::Pid do
  it "has a version number" do
    expect(Hyrax::Pid::VERSION).not_to be nil
  end

  describe ".configure" do
    after { described_class.instance_variable_set(:@configuration, nil) }

    it "yields the shared configuration" do
      described_class.configure { |config| config.data_cite.field_mapping = {title: :title} }
      expect(described_class.configuration.data_cite.field_mapping).to eq(title: :title)
    end
  end

  describe ".service_definition" do
    it "finds a service by key" do
      expect(described_class.service_definition(:datacite).label).to eq("DataCite")
    end

    it "raises for an unknown service" do
      expect { described_class.service_definition("nope") }.to raise_error(Hyrax::Pid::Error, /nope/)
    end
  end
end
