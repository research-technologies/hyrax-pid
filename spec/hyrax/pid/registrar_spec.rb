# frozen_string_literal: true

# Hyrax isn't a dependency of this gem, so stand in for the base class with
# the same shape Hyrax::Identifier::Registrar has (builder: kwarg, builder
# accessor, abstract #register!).
module Hyrax
  module Identifier
    unless const_defined?(:Registrar)
      class Registrar
        attr_accessor :builder

        def initialize(builder:)
          @builder = builder
        end

        def register!(*)
          raise NotImplementedError
        end
      end
    end
  end
end

require "hyrax/pid/registrar"

RSpec.describe Hyrax::Pid::Registrar do
  subject(:registrar) { described_class.new(key: :doi, attribute: :doi, mapper: mapper, builder: builder) }

  let(:builder) { double("builder") }
  let(:mapper) { instance_double(Hyrax::Pid::DataCite::MetadataMapper, build: metadata) }
  let(:metadata) { {titles: [{title: "A work"}]} }
  let(:minter) { instance_double(Hyrax::Pid::DataCite::Minter) }
  let(:minted) { Hyrax::Pid::Identifier.new(value: "10.0000/new", type: :doi, state: :draft) }

  around do |example|
    original = Hyrax::Pid::Registry.send(:registrations).dup
    Hyrax::Pid::Registry.register(:doi, minter)
    example.run
    Hyrax::Pid::Registry.clear
    original.each { |key, value| Hyrax::Pid::Registry.register(key, value) }
  end

  it "satisfies the Hyrax::Identifier::Registrar contract" do
    allow(minter).to receive(:mint).and_return(minted)
    work = Struct.new(:id, :doi).new("work_id", nil)

    expect(registrar).to have_attributes(builder: builder)
    expect(registrar.register!(object: work).identifier).to respond_to(:to_str)
  end

  it "defaults to the configured DataCite mapper" do
    expect(described_class.new.mapper).to be_a(Hyrax::Pid::DataCite::MetadataMapper)
  end

  describe "#register!" do
    it "mints when the work has no identifier yet" do
      work = Struct.new(:doi).new(nil)
      expect(minter).to receive(:mint).with(metadata: metadata).and_return(minted)

      expect(registrar.register!(object: work).identifier).to eq("10.0000/new")
    end

    it "treats a blank identifier as absent" do
      work = Struct.new(:doi).new("")
      expect(minter).to receive(:mint).and_return(minted)

      registrar.register!(object: work)
    end

    it "updates when the work already has an identifier" do
      work = Struct.new(:doi).new(["10.0000/old"])
      updated = Hyrax::Pid::Identifier.new(value: "10.0000/old", type: :doi)
      expect(minter).to receive(:update).with(identifier: "10.0000/old", metadata: metadata).and_return(updated)

      expect(registrar.register!(object: work).identifier).to eq("10.0000/old")
    end

    it "mints when the work has no such attribute at all" do
      work = Object.new
      expect(minter).to receive(:mint).and_return(minted)

      registrar.register!(object: work)
    end

    it "propagates mapper errors without touching the minter" do
      allow(mapper).to receive(:build).and_raise(Hyrax::Pid::Error, "creator is blank")
      expect(minter).not_to receive(:mint)

      expect { registrar.register!(object: Object.new) }.to raise_error(Hyrax::Pid::Error, /creator/)
    end
  end
end
