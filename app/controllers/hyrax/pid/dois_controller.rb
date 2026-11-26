# frozen_string_literal: true

module Hyrax
  module Pid
    # Admin DOI actions, triggered from a work's show page: mint (or update the
    # metadata of) a draft DOI, and register it (make it findable).
    class DoisController < ::ApplicationController
      PUBLIC = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC

      def create
        work = Hyrax.query_service.find_by(id: params[:id])
        authorize! :manage, :pid
        work = with_current_schema(work)

        # Built here only for the flash summary; the registrar builds its own
        # copy, since Dispatcher returns the work rather than the registrar's record.
        metadata = Hyrax::Pid.configuration.data_cite.metadata_mapper.build(work)
        # The registrar updates rather than mints when the work already has a
        # DOI, so the flash needs to know which happened.
        updating = existing_doi(work).present?
        begin
          work = Hyrax::Identifier::Dispatcher
                 .for(:doi, landing_page_url: method(:landing_page_url))
                 .assign_for!(object: work, attribute: :doi)
        rescue NoMethodError => e
          # Valkyrie resources set flexible-schema attributes via method_missing,
          # so respond_to?(:doi=) can't predict this; catch the real failure.
          raise e unless e.name == :doi=
          raise Hyrax::Pid::Error, "#{work.class} has no :doi attribute (flexible schema not applied?)"
        end
        # Dispatcher persists but doesn't publish, so reindex here.
        Hyrax.publisher.publish("object.metadata.updated", object: work, user: current_user)

        redirect_to [main_app, work], notice: t(updating ? ".updated" : ".success", doi: Array(work.doi).first, summary: metadata_summary(metadata))
      rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
        redirect_to main_app.root_path, alert: t(".not_found")
      rescue Hyrax::Pid::Error => e
        redirect_to [main_app, work], alert: t(updating ? ".update_failure" : ".failure", message: e.message)
      end

      # Takes the work's DOI one step along this tenant's workflow: to
      # findable, or to registered first (see Hyrax::Pid::DataCite::Workflow).
      # Only for public works: the DOI's landing page has to be visible, and a
      # findable DOI can't be deleted.
      def register
        work = Hyrax.query_service.find_by(id: params[:id])
        authorize! :manage, :pid
        doi = existing_doi(work)
        raise Hyrax::Pid::Error, "this work has no DOI yet" unless doi
        raise Hyrax::Pid::Error, "only public works can be registered" unless work.visibility == PUBLIC

        step = Hyrax::Pid::LifecycleStep.for(work.id)
        raise Hyrax::Pid::Error, "this DOI is already findable" unless step

        identifier = Hyrax::Pid::Service.minter_for!("datacite").transition(identifier: doi, event: step.event)
        Hyrax::Pid::Registration.record!(resource_id: work.id, identifier: identifier)

        redirect_to [main_app, work], notice: t(".success.#{step.name}", doi: identifier.value)
      rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
        redirect_to main_app.root_path, alert: t(".not_found")
      rescue Hyrax::Pid::Error => e
        redirect_to [main_app, work], alert: t(".failure", message: e.message)
      end

      private

      # A flexible-schema work gets its attributes when it's loaded, from the
      # schema_version saved on it, so a work last saved before the `doi`
      # property existed has no `doi=`. Setting schema_version on the loaded
      # object doesn't change that; it has to be rebuilt, as
      # Hyrax::Forms::ResourceForm does when the edit form is opened.
      def with_current_schema(work)
        return work unless work.respond_to?(:flexible?) && work.flexible?

        current = Hyrax::FlexibleSchema.current_schema_id
        return work if work.schema_version.to_s == current.to_s

        work.class.new(work.attributes.dup.merge(schema_version: current))
      end

      # Same probe as Hyrax::Pid::Registrar#existing_identifier: flexible-schema
      # attributes answer via method_missing, so respond_to? can't be used.
      def existing_doi(work)
        Array(work.public_send(:doi)).first.presence
      rescue NoMethodError
        nil
      end

      # Built from the current request, so in Hyku it carries the tenant's own
      # host. locale: nil keeps Hyrax's ?locale= param out of a permanent URL.
      def landing_page_url(work)
        main_app.polymorphic_url(work, locale: nil)
      end

      # Plain text, not HTML: the flash partial escapes it, and safe HTML built
      # from user-entered contributor/title data isn't worth the risk here.
      def metadata_summary(metadata)
        creators = metadata[:creators].map { |creator| creator[:name] }.join(", ")
        parts = [
          "Title: #{metadata[:titles].first[:title]}",
          "Creator(s): #{creators}",
          "Publisher: #{metadata[:publisher]}",
          "Publication year: #{metadata[:publicationYear]}",
          "Resource type: #{metadata.dig(:types, :resourceTypeGeneral)}"
        ]
        parts << "Related items: #{metadata[:relatedItems].size}" if metadata[:relatedItems].present?
        parts.join(" | ")
      end
    end
  end
end
