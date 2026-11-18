# frozen_string_literal: true

RSpec.describe Hyrax::Pid::Configuration do
  describe "#data_cite" do
    it "defaults field_mapping to an empty hash" do
      expect(subject.data_cite.field_mapping).to eq({})
    end

    it "builds a MetadataMapper from field_mapping" do
      subject.data_cite.field_mapping = {title: :title}

      mapper = subject.data_cite.metadata_mapper
      expect(mapper).to be_a(Hyrax::Pid::DataCite::MetadataMapper)
    end

    it "holds an injectable client (e.g. a fake, for demo/test environments)" do
      fake_client = instance_double("Hyrax::Pid::DataCite::Client")
      subject.data_cite.client = fake_client

      expect(subject.data_cite.client).to eq(fake_client)
    end
  end
end
