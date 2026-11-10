# frozen_string_literal: true

# Not required by lib/hyrax/pid.rb: it subclasses Hyrax::Identifier::Registrar,
# so it only loads inside a Hyrax app. Hosts require it explicitly, e.g.
#
#   Rails.application.config.to_prepare do
#     require "hyrax/pid/registrar"
#     Hyrax.config.identifier_registrars = { doi: Hyrax::Pid::Registrar }
#   end
#
# after which Hyrax::Identifier::Dispatcher.for(:doi).assign_for!(object:, attribute: :doi)
# mints (or updates) through this gem's Registry/Minter.
module Hyrax
  module Pid
    class Registrar < ::Hyrax::Identifier::Registrar
      Record = Struct.new(:identifier)

      attr_reader :key, :attribute, :mapper

      # @param key       [Symbol] Hyrax::Pid::Registry key
      # @param attribute [Symbol] the work attribute holding any existing identifier
      # @param mapper    [#build] turns a work into the minter's metadata payload
      # @param builder   accepted for Hyrax::Identifier::Registrar's interface; unused,
      #   since remote services (DataCite, RAiD) mint the identifier string themselves
      def initialize(key: :doi, attribute: :doi,
                     mapper: Hyrax::Pid.configuration.data_cite.metadata_mapper,
                     builder: nil)
        super(builder: builder)
        @key = key
        @attribute = attribute
        @mapper = mapper
      end

      # @param object [Object] the work
      # @return [Record] responds to #identifier, per Hyrax::Identifier::Registrar
      def register!(object:)
        metadata = mapper.build(object)
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
