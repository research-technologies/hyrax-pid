# frozen_string_literal: true

RSpec.describe Hyrax::Pid::Configuration do
  describe "#data_cite" do
    it "defaults to production (non-sandbox)" do
      expect(subject.data_cite.sandbox).to eq(false)
    end

    it "builds a configured DataCite::Minter" do
      subject.data_cite.prefix = "10.1234"
      subject.data_cite.username = "user"
      subject.data_cite.password = "pass"
      subject.data_cite.sandbox = true

      minter = subject.data_cite.minter
      expect(minter).to be_a(Hyrax::Pid::DataCite::Minter)
      expect(minter.identifier_type).to eq(:doi)
    end

    it "injects a configured client (e.g. a fake, for demo/test environments)" do
      fake_client = instance_double("Hyrax::Pid::DataCite::Client")
      subject.data_cite.prefix = "10.1234"
      subject.data_cite.username = "user"
      subject.data_cite.password = "pass"
      subject.data_cite.client = fake_client

      expect(subject.data_cite.minter.instance_variable_get(:@client)).to eq(fake_client)
    end

    it "defaults field_mapping to an empty hash" do
      expect(subject.data_cite.field_mapping).to eq({})
    end

    it "builds a MetadataMapper from field_mapping" do
      subject.data_cite.field_mapping = {title: :title}

      mapper = subject.data_cite.metadata_mapper
      expect(mapper).to be_a(Hyrax::Pid::DataCite::MetadataMapper)
    end
  end
end
