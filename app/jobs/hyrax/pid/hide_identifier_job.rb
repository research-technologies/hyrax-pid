# frozen_string_literal: true

module Hyrax
  module Pid
    # Hides a findable DOI (back to registered) once its work stops being
    # public, e.g. made private or put under embargo. Enqueued by
    # Hyrax::Pid::Listener; re-checks everything against the saved work, since
    # the listener only filters on the recorded state.
    class HideIdentifierJob < ::Hyrax::ApplicationJob
      PUBLIC = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      # @param resource_id [String]
      def perform(resource_id)
        registration = Hyrax::Pid::Registration.for(resource_id)
        return unless registration&.state == "findable"

        work = Hyrax.query_service.find_by(id: resource_id)
        return if work.visibility == PUBLIC

        identifier = Hyrax::Pid::Service.minter_for!("datacite").hide(identifier: registration.identifier)
        Hyrax::Pid::Registration.record!(resource_id: resource_id, identifier: identifier)
      rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
        nil # deleted since; nothing to point the DOI at anyway
      end
    end
  end
end
