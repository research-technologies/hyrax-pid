# frozen_string_literal: true

RSpec.describe Hyrax::Pid::DataCite::MetadataMapper do
  let(:work) { instance_double("Work", id: "abc123", title: ["A Title"], creator: ["A Creator"]) }
  let(:mapping) do
    {
      title: :title,
      creator: :creator,
      publisher: ->(_work) { "Enact" },
      publication_year: ->(_work) { 2026 },
      resource_type_general: "Other"
    }
  end

  subject { described_class.new(mapping: mapping) }

  describe "#build" do
    it "builds a DataCite attributes hash, taking the first value of multi-valued fields" do
      expect(subject.build(work)).to eq(
        titles: [{title: "A Title"}],
        creators: [{name: "A Creator"}],
        publisher: "Enact",
        publicationYear: 2026,
        types: {resourceTypeGeneral: "Other"}
      )
    end

    it "raises if a required field has no mapping configured" do
      mapping.delete(:publisher)

      expect { subject.build(work) }.to raise_error(Hyrax::Pid::Error, /No DataCite field mapping configured for :publisher/)
    end

    it "raises listing all required fields that resolve blank" do
      allow(work).to receive(:title).and_return([])
      allow(work).to receive(:creator).and_return(nil)

      expect { subject.build(work) }.to raise_error(Hyrax::Pid::Error, /title, creator/)
    end

    context "when :creator resolves to an Array of Hashes" do
      let(:mapping) do
        super().merge(
          creator: lambda { |_work|
            [
              {name: "Jane Doe", nameType: "Personal", nameIdentifiers: [{nameIdentifier: "0000-0001", nameIdentifierScheme: "ORCID"}]},
              {name: "An Org", nameType: "Organizational"}
            ]
          }
        )
      end

      it "uses the Hashes verbatim as multiple DataCite creators, instead of collapsing to one" do
        expect(subject.build(work)[:creators]).to eq(
          [
            {name: "Jane Doe", nameType: "Personal", nameIdentifiers: [{nameIdentifier: "0000-0001", nameIdentifierScheme: "ORCID"}]},
            {name: "An Org", nameType: "Organizational"}
          ]
        )
      end

      it "treats an empty creators Array as a blank required field" do
        mapping[:creator] = ->(_work) { [] }

        expect { subject.build(work) }.to raise_error(Hyrax::Pid::Error, /creator/)
      end
    end

    context "with an optional field (:related_items) mapped" do
      let(:mapping) { super().merge(related_items: ->(_work) { [{relationType: "References", relatedItemType: "Dataset"}] }) }

      it "includes it under its DataCite attribute name (relatedItems)" do
        expect(subject.build(work)[:relatedItems]).to eq([{relationType: "References", relatedItemType: "Dataset"}])
      end
    end

    context "with an optional field mapped but resolving blank" do
      let(:mapping) { super().merge(related_items: ->(_work) { [] }) }

      it "omits it from the result rather than including an empty Array" do
        expect(subject.build(work)).not_to have_key(:relatedItems)
      end
    end

    it "omits an optional field's key entirely when not mapped at all" do
      expect(subject.build(work)).not_to have_key(:relatedItems)
    end
  end
end
