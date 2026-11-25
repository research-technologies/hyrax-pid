# frozen_string_literal: true

RSpec.describe Hyrax::Pid::DataCite::Workflow do
  def step_name(key, state)
    described_class.new(key).next_step(state)&.name
  end

  it "falls back to draft -> findable for a blank or unknown key" do
    expect(described_class.new(nil).key).to eq("draft_findable")
    expect(described_class.new("nonsense").key).to eq("draft_findable")
  end

  describe "draft -> findable" do
    it "publishes a draft, an unknown state, or a hidden (registered) DOI" do
      expect(step_name("draft_findable", "draft")).to eq("publish")
      expect(step_name("draft_findable", nil)).to eq("publish")
      expect(step_name("draft_findable", :registered)).to eq("publish")
    end

    it "has nothing left to do once findable" do
      expect(step_name("draft_findable", "findable")).to be_nil
    end
  end

  describe "draft -> registered -> findable" do
    it "registers a draft or an unknown state first" do
      expect(step_name("draft_registered_findable", "draft")).to eq("register")
      expect(step_name("draft_registered_findable", nil)).to eq("register")
    end

    it "then makes a registered DOI findable" do
      step = described_class.new("draft_registered_findable").next_step("registered")

      expect(step).to have_attributes(name: "make_findable", event: "publish")
    end

    it "has nothing left to do once findable" do
      expect(step_name("draft_registered_findable", "findable")).to be_nil
    end
  end
end
