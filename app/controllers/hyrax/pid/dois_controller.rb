# frozen_string_literal: true

module Hyrax
  module Pid
    # Admin "Mint DOI" action, triggered from a work's show page.
    class DoisController < ::ApplicationController
      def create
        work = Hyrax.query_service.find_by(id: params[:id])
        authorize! :manage, :pid
        # A flexible-schema work's schema_version is only bumped when it's saved
        # through Hyrax::Forms::ResourceForm, so a work last saved before the
        # `doi` property existed can be stuck on a version without it. Bump it
        # here, as resaving through the edit form would.
        if work.respond_to?(:schema_version=)
          work.schema_version = Hyrax::FlexibleSchema.current_schema_id
        end

        # Built here only for the flash summary; the registrar builds its own
        # copy, since Dispatcher returns the work rather than the registrar's record.
        metadata = Hyrax::Pid.configuration.data_cite.metadata_mapper.build(work)
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

        redirect_to [main_app, work], notice: t(".success", doi: Array(work.doi).first, summary: metadata_summary(metadata))
      rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
        redirect_to main_app.root_path, alert: t(".not_found")
      rescue Hyrax::Pid::Error => e
        redirect_to [main_app, work], alert: t(".failure", message: e.message)
      end

      private

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
