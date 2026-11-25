# frozen_string_literal: true

module Hyrax
  module Pid
    # Subscribed to Hyrax.publisher by Hyrax::Pid::Engine. Hyrax publishes
    # 'object.acl.updated' whenever a resource's access controls are saved:
    # visibility changes from the edit form, and embargoes and leases being
    # applied or lifted.
    class Listener
      # @param event [Dry::Events::Event]
      def on_object_acl_updated(event)
        return unless event[:result] == :success

        resource = event[:acl].resource
        return unless resource.respond_to?(:work?) && resource.work?
        return unless Hyrax::Pid::Registration.for(resource.id)&.state == "findable"

        # Visibility is checked in the job, against the saved work.
        Hyrax::Pid::HideIdentifierJob.perform_later(resource.id.to_s)
      rescue StandardError => e
        # Never let a PID problem break saving a work's permissions.
        Rails.logger.error("[hyrax-pid] couldn't check #{resource&.id} for DOI hiding: #{e.class}: #{e.message}")
      end
    end
  end
end
