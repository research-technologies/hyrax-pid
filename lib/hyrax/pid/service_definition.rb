# frozen_string_literal: true

module Hyrax
  module Pid
    # The admin-editable settings for one PID service. The settings page builds
    # its form from this, so adding a service means adding a definition, not views.
    class ServiceDefinition
      # @!attribute secret
      #   Stored encrypted and never shown again once saved.
      Field = Struct.new(:name, :type, :secret, :required, :default, keyword_init: true)

      TRUE_VALUES = %w[1 true on].freeze

      attr_reader :key, :label, :fields

      # @param key [String] stored in Hyrax::Pid::Service#service
      # @param label [String]
      # @param fields [Array<Field>]
      def initialize(key:, label:, fields:)
        @key = key
        @label = label
        @fields = fields
      end

      # Applies submitted form values to stored settings and secrets. A blank
      # secret keeps the stored value, since secrets are never sent back to the form.
      #
      # @param params [Hash{String=>String}]
      # @return [Array(Hash, Hash)] new settings and secrets
      def merge(params, settings:, secrets:)
        settings = settings.dup
        secrets = secrets.dup

        fields.each do |field|
          next unless params.key?(field.name)
          value = params[field.name].to_s

          if field.secret
            secrets[field.name] = value unless value.empty?
          elsif field.type == :boolean
            settings[field.name] = TRUE_VALUES.include?(value)
          else
            settings[field.name] = value.strip
          end
        end

        [settings, secrets]
      end

      # @return [Array<String>] names of required fields with no value
      def missing(settings:, secrets:)
        fields.select(&:required).filter_map do |field|
          value = (field.secret ? secrets : settings)[field.name]
          field.name if value.to_s.strip.empty?
        end
      end
    end
  end
end
