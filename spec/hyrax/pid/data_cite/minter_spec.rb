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

  %w[register hide].each do |event|
    describe "##{event}" do
      it "updates the DOI with a #{event} event" do
        expect(client).to receive(:call).with(
          method: :put,
          path: "/dois/10.1234/abcd",
          body: {data: {type: "dois", attributes: {event: event}}}
        ).and_return(datacite_response(state: "registered"))

        expect(minter.public_send(event, identifier: "10.1234/abcd").state).to eq(:registered)
      end
    end
  end

  describe "#check_connection" do
    it "asks the client to check the credentials against the prefix" do
      result = Hyrax::Pid::ConnectionCheck.new(ok: true, message: "fine")
      allow(client).to receive(:check_credentials).with(prefix: "10.1234").and_return(result)

      expect(minter.check_connection).to eq(result)
    end

    it "fails cleanly for a client that can't check credentials" do
      minter = described_class.new(prefix: "10.1234", username: "u", password: "p", client: ->(**) {})

      expect(minter.check_connection).to have_attributes(ok?: false)
    end

    it "points the default client at the matching MDS host" do
      minter = described_class.new(prefix: "10.1234", username: "u", password: "p", sandbox: true)

      expect(minter.instance_variable_get(:@client).instance_variable_get(:@mds_host))
        .to eq(described_class::SANDBOX_MDS_HOST)
    end
  end
end
