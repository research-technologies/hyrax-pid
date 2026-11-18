# frozen_string_literal: true

RSpec.describe Hyrax::Pid::ServiceDefinition do
  subject(:definition) { Hyrax::Pid.service_definition("datacite") }

  describe "#merge" do
    let(:stored_settings) { {"prefix" => "10.1234", "username" => "ORG.REPO", "sandbox" => true} }
    let(:stored_secrets) { {"password" => "old"} }

    def merge(params)
      definition.merge(params, settings: stored_settings, secrets: stored_secrets)
    end

    it "puts secret fields in secrets and the rest in settings" do
      settings, secrets = merge("prefix" => "10.5555", "password" => "new")

      expect(settings).to include("prefix" => "10.5555")
      expect(settings).not_to have_key("password")
      expect(secrets).to eq("password" => "new")
    end

    it "keeps a stored secret when the submitted value is blank" do
      _settings, secrets = merge("password" => "")

      expect(secrets).to eq("password" => "old")
    end

    it "strips settings but not secrets" do
      settings, secrets = merge("prefix" => " 10.5555 ", "password" => " pass ")

      expect(settings["prefix"]).to eq("10.5555")
      expect(secrets["password"]).to eq(" pass ")
    end

    it "casts checkbox values to booleans" do
      expect(merge("sandbox" => "0").first["sandbox"]).to be(false)
      expect(merge("sandbox" => "1").first["sandbox"]).to be(true)
    end

    it "leaves fields that weren't submitted alone" do
      settings, = merge("prefix" => "10.5555")

      expect(settings).to include("username" => "ORG.REPO", "sandbox" => true)
    end

    it "doesn't change the stored hashes" do
      merge("prefix" => "10.5555", "password" => "new")

      expect(stored_settings["prefix"]).to eq("10.1234")
      expect(stored_secrets["password"]).to eq("old")
    end
  end

  describe "#missing" do
    it "lists required fields without a value, settings and secrets alike" do
      expect(definition.missing(settings: {"prefix" => " "}, secrets: {})).to eq(%w[prefix username password])
    end

    it "is empty when every required field has a value" do
      settings = {"prefix" => "10.1234", "username" => "ORG.REPO"}

      expect(definition.missing(settings: settings, secrets: {"password" => "x"})).to be_empty
    end
  end
end
