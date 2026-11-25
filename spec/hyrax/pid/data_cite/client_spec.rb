# frozen_string_literal: true

RSpec.describe Hyrax::Pid::DataCite::Client do
  subject(:client) do
    described_class.new(host: "https://api.test.datacite.org", mds_host: "https://mds.test.datacite.org",
                        username: "ORG.REPO", password: "secret")
  end

  describe "#check_credentials" do
    let(:requests) { [] }

    def response(klass, code, body = "")
      klass.new("1.1", code, "").tap { |r| allow(r).to receive(:body).and_return(body) }
    end

    def repository_record(*prefixes)
      {data: {id: "org.repo", relationships: {prefixes: {data: prefixes.map { |p| {id: p, type: "prefixes"} }}}}}.to_json
    end

    # Answers MDS and REST separately, and keeps every request made.
    def stub_datacite(mds:, rest: nil)
      allow(Net::HTTP).to receive(:start) do |host, *_args, &block|
        http = double("http")
        allow(http).to receive(:request) do |request|
          requests << [host, request]
          host.start_with?("mds.") ? mds : rest
        end
        block.call(http)
      end
    end

    it "checks credentials with a HEAD on MDS's DOI list, and nothing per-DOI" do
      stub_datacite(mds: response(Net::HTTPOK, "200"), rest: response(Net::HTTPOK, "200", repository_record("10.80000")))

      client.check_credentials(prefix: "10.80000")

      host, request = requests.first
      expect(host).to eq("mds.test.datacite.org")
      expect(request).to be_a(Net::HTTP::Head)
      expect(request.path).to eq("/doi")
      expect(request["authorization"]).to eq("Basic #{['ORG.REPO:secret'].pack('m0')}")
    end

    it "is ok when the credentials are accepted and the prefix is the repository's" do
      stub_datacite(mds: response(Net::HTTPOK, "200"), rest: response(Net::HTTPOK, "200", repository_record("10.80000")))

      result = client.check_credentials(prefix: "10.80000")

      expect(result.ok?).to be(true)
      expect(requests.last.last.path).to eq("/clients/ORG.REPO")
    end

    it "fails on a 401 (wrong repository ID or password), without looking up the prefix" do
      stub_datacite(mds: response(Net::HTTPUnauthorized, "401", "Bad credentials"))

      result = client.check_credentials(prefix: "10.80000")

      expect(result.ok?).to be(false)
      expect(result.message).to match(/rejected/)
      expect(requests.size).to eq(1)
    end

    it "fails when the prefix isn't assigned to the repository, naming the ones that are" do
      stub_datacite(mds: response(Net::HTTPOK, "200"), rest: response(Net::HTTPOK, "200", repository_record("10.11111")))

      result = client.check_credentials(prefix: "10.80000")

      expect(result.ok?).to be(false)
      expect(result.message).to include("10.80000", "10.11111")
    end

    it "fails on any other MDS answer" do
      stub_datacite(mds: response(Net::HTTPInternalServerError, "500"))

      expect(client.check_credentials(prefix: "10.80000")).to have_attributes(ok?: false)
    end

    it "fails without raising when DataCite can't be reached" do
      allow(Net::HTTP).to receive(:start).and_raise(SocketError, "getaddrinfo failed")

      result = client.check_credentials(prefix: "10.80000")

      expect(result.ok?).to be(false)
      expect(result.message).to include("getaddrinfo")
    end
  end
end
