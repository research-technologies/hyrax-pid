# frozen_string_literal: true

# Loaded and registered as Hyrax.config.identifier_registrars[:doi] by
# Hyrax::Pid::Engine; it subclasses a Hyrax class, so it can't load earlier.
module Hyrax
  module Pid
    class Registrar < ::Hyrax::Identifier::Registrar
      Record = Struct.new(:identifier)

      attr_reader :key, :attribute, :mapper, :landing_page_url

      # @param key       [Symbol] Hyrax::Pid::Registry key
      # @param attribute [Symbol] the work attribute holding any existing identifier
      # @param mapper    [#build] turns a work into the minter's metadata payload
      # @param landing_page_url [#call, nil] work -> URL the identifier resolves to.
      #   DataCite requires one before a DOI can be made findable. Passed per call
      #   rather than configured, because the right host (per tenant in Hyku)
      #   is only known from the current request.
      # @param builder   accepted for Hyrax::Identifier::Registrar's interface; unused,
      #   since remote services (DataCite, RAiD) mint the identifier string themselves
      def initialize(key: :doi, attribute: :doi,
                     mapper: Hyrax::Pid.configuration.data_cite.metadata_mapper,
                     landing_page_url: nil,
                     builder: nil)
        super(builder: builder)
        @key = key
        @attribute = attribute
        @mapper = mapper
        @landing_page_url = landing_page_url
      end

      # @param object [Object] the work
      # @return [Record] responds to #identifier, per Hyrax::Identifier::Registrar
      def register!(object:)
        metadata = mapper.build(object)
        metadata = metadata.merge(url: landing_page_url.call(object)) if landing_page_url
        existing = existing_identifier(object)

        identifier =
          if existing
            minter.update(identifier: existing, metadata: metadata)
          else
            minter.mint(metadata: metadata)
          end

        Record.new(identifier.value)
      end

      private

      def minter
        Hyrax::Pid::Registry.minter_for(key)
      end

      # Flexible-schema (Valkyrie) attributes answer via method_missing, so
      # respond_to? can't be used to probe for the attribute.
      def existing_identifier(object)
        value = Array(object.public_send(attribute)).first
        value.nil? || value.to_s.empty? ? nil : value.to_s
      rescue NoMethodError
        nil
      end
    end
  end
end
