# frozen_string_literal: true

module Hyrax
  module Pid
    module DataCite
      # The steps a tenant's DOIs go through after minting (always a draft),
      # chosen on the PID services settings page.
      #
      # - "draft_findable": draft -> findable.
      # - "draft_registered_findable": draft -> registered (resolves, but kept
      #   out of DataCite's search and metadata feeds) -> findable.
      #
      # Either way, a findable DOI whose work stops being public is hidden
      # (back to registered) by Hyrax::Pid::HideIdentifierJob.
      class Workflow
        DEFAULT = "draft_findable"
        KEYS = %w[draft_findable draft_registered_findable].freeze

        # @!attribute name
        #   @return [String] names the step's button label, confirmation and
        #     flash message (hyrax.pid.register_button.<name>.*)
        # @!attribute event
        #   @return [String] the DataCite event that takes this step
        Step = Struct.new(:name, :event, keyword_init: true)

        # draft -> findable, in the one-step workflow
        PUBLISH = Step.new(name: "publish", event: "publish")
        # draft -> registered, in the two-step workflow
        REGISTER = Step.new(name: "register", event: "register")
        # registered -> findable, in the two-step workflow
        MAKE_FINDABLE = Step.new(name: "make_findable", event: "publish")

        attr_reader :key

        # @param key [String, nil] unknown or blank keys fall back to DEFAULT
        def initialize(key)
          @key = KEYS.include?(key.to_s) ? key.to_s : DEFAULT
        end

        # @param state [String, Symbol, nil] the DOI's last known state; nil
        #   when it isn't known (minted before states were recorded)
        # @return [Step, nil] nil once the DOI is findable
        def next_step(state)
          state = state&.to_s
          return nil if state == "findable"

          if key == "draft_registered_findable"
            state == "registered" ? MAKE_FINDABLE : REGISTER
          else
            # Includes "registered", which a hidden DOI is in.
            PUBLISH
          end
        end
      end
    end
  end
end
