# frozen_string_literal: true

module Hyrax
  module Pid
    # One configured PID service (DataCite, ...). In Hyku each tenant has its
    # own table, since Apartment gives every non-excluded model a per-tenant schema.
    class Service < ::ActiveRecord::Base
      serialize :secrets, coder: JSON
      encrypts :secrets

      validates :service, presence: true, uniqueness: true, inclusion: { in: ->(_) { Hyrax::Pid::SERVICES.keys } }
      validate :required_fields_present, if: -> { Hyrax::Pid::SERVICES.key?(service) }

      class << self
        # Doesn't decrypt anything, so it's safe to call on every request.
        # @param key [String]
        def configured?(key)
          find_by(service: key)&.configured? || false
        end

        # @param key [String]
        # @return [Hyrax::Pid::Minter]
        # @raise [Hyrax::Pid::Error] if the service isn't set up or can't be decrypted
        def minter_for!(key)
          record = find_by(service: key)
          unless record&.configured?
            raise Error, "#{Hyrax::Pid.service_definition(key).label} isn't set up for this repository"
          end
          record.minter
        rescue ActiveRecord::Encryption::Errors::Base => e
          raise Error, "Stored #{key} credentials can't be decrypted; check the Active Record encryption keys (#{e.class.name.demodulize})"
        end
      end

      def definition
        Hyrax::Pid.service_definition(service)
      end

      # Required settings are present and secrets have been saved. Required
      # secrets are validated on save, so the stored ciphertext's presence is
      # enough and nothing needs decrypting.
      def configured?
        return false unless persisted? && secrets_before_type_cast.present?

        definition.fields.select(&:required).reject(&:secret).all? { |field| setting(field).to_s.strip.present? }
      end

      # @param params [Hash{String=>String}] submitted form values
      def apply(params)
        self.settings, self.secrets = definition.merge(params.to_h.stringify_keys, settings: settings || {}, secrets: secrets || {})
      end

      # @param field [Hyrax::Pid::ServiceDefinition::Field]
      def setting(field)
        (settings || {}).fetch(field.name) { field.default }
      end

      def secret_set?(name)
        (secrets || {})[name].present?
      end

      def sandbox?
        setting(field("sandbox")) == true
      end

      # @return [Hyrax::Pid::DataCite::Workflow]
      def workflow
        Hyrax::Pid::DataCite::Workflow.new(setting(field("workflow")))
      end

      # @return [Hyrax::Pid::Minter]
      def minter
        case service
        when "datacite"
          Hyrax::Pid::DataCite::Minter.new(
            prefix: settings["prefix"],
            username: settings["username"],
            password: secrets["password"],
            sandbox: sandbox?,
            client: Hyrax::Pid.configuration.data_cite.client
          )
        end
      end

      private

      def field(name)
        definition.fields.find { |f| f.name == name }
      end

      def required_fields_present
        definition.missing(settings: settings || {}, secrets: secrets || {}).each do |name|
          errors.add(name.to_sym, :blank)
        end
      end
    end
  end
end
