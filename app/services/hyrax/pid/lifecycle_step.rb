# frozen_string_literal: true

module Hyrax
  module Pid
    # The next lifecycle step for a work's DOI, from this tenant's chosen
    # workflow and the DOI's last recorded state. Shared by the "Register DOI"
    # button and the action it posts to, so the two can't disagree.
    #
    # Note for file names under app/: avoid "doi" as a word (e.g. doi_step.rb).
    # hyrax-doi, which Hyku loads, makes "DOI" an acronym app-wide, so Zeitwerk
    # would expect DOIStep there instead of DoiStep.
    module LifecycleStep
      # @param resource_id [#to_s]
      # @return [Hyrax::Pid::DataCite::Workflow::Step, nil]
      def self.for(resource_id)
        service = Hyrax::Pid::Service.find_by(service: "datacite")
        return nil unless service

        service.workflow.next_step(Hyrax::Pid::Registration.for(resource_id)&.state)
      end
    end
  end
end
