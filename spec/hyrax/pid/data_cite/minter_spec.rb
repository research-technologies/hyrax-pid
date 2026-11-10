# frozen_string_literal: true

RSpec.describe Hyrax::Pid::DataCite::Minter do
  let(:client) { instance_double(Hyrax::Pid::DataCite::Client) }
  let(:minter) do
    described_class.new(prefix: "10.1234", username: "user", password: "pass", client: client)
  end

  def datacite_response(doi: "10.1234/abcd", state: "draft")
    {"data" => {"id" => doi, "type" => "dois", "attributes" => {"doi" => doi, "state" => state}}}
  end

  describe "#identifier_type" do
    it { expect(minter.identifier_type).to eq(:doi) }
  end

  describe "#mint" do
    it "POSTs a draft DOI payload and returns an Identifier" do
      expect(client).to receive(:call).with(
        method: :post,
        path: "/dois",
        body: {data: {type: "dois", attributes: {titles: [{title: "Test"}], prefix: "10.1234"}}}
      ).and_return(datacite_response)

      identifier = minter.mint(metadata: {titles: [{title: "Test"}]})

      expect(identifier).to be_a(Hyrax::Pid::Identifier)
      expect(identifier.value).to eq("10.1234/abcd")
      expect(identifier.type).to eq(:doi)
      expect(identifier.state).to eq(:draft)
    end
  end

  describe "#update" do
    it "PUTs the metadata to the DOI's path" do
      expect(client).to receive(:call).with(
        method: :put,
        path: "/dois/10.1234/abcd",
        body: {data: {type: "dois", attributes: {titles: [{title: "Updated"}]}}}
      ).and_return(datacite_response(state: "registered"))

      identifier = minter.update(identifier: "10.1234/abcd", metadata: {titles: [{title: "Updated"}]})

      expect(identifier.state).to eq(:registered)
    end
  end

  describe "#find" do
    it "GETs the DOI's path" do
      expect(client).to receive(:call).with(method: :get, path: "/dois/10.1234/abcd").and_return(datacite_response)

      identifier = minter.find(identifier: "10.1234/abcd")

      expect(identifier.value).to eq("10.1234/abcd")
    end
  end

  describe "#publish" do
    it "updates the DOI with a publish event" do
      expect(client).to receive(:call).with(
        method: :put,
        path: "/dois/10.1234/abcd",
        body: {data: {type: "dois", attributes: {event: "publish"}}}
      ).and_return(datacite_response(state: "findable"))

      identifier = minter.publish(identifier: "10.1234/abcd")

      expect(identifier.state).to eq(:findable)
    end
  end
end
