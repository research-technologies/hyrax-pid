# frozen_string_literal: true

require_relative "pid/version"
require_relative "pid/error"
require_relative "pid/identifier"
require_relative "pid/minter"
require_relative "pid/registry"
require_relative "pid/configuration"
require_relative "pid/service_definition"
require_relative "pid/data_cite/client"
require_relative "pid/data_cite/metadata_mapper"
require_relative "pid/data_cite/minter"

module Hyrax
  module Pid
    # Services an admin can configure on the PID services settings page.
    SERVICES = {
      "datacite" => ServiceDefinition.new(
        key: "datacite",
        label: "DataCite",
        fields: [
          ServiceDefinition::Field.new(name: "prefix", type: :string, required: true),
          ServiceDefinition::Field.new(name: "username", type: :string, required: true),
          ServiceDefinition::Field.new(name: "password", type: :string, secret: true, required: true),
          # Defaults on so a newly configured service can't mint real DOIs by accident.
          ServiceDefinition::Field.new(name: "sandbox", type: :boolean, default: true)
        ]
      )
    }.freeze

    class << self
      # @return [Hyrax::Pid::Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # @yieldparam configuration [Hyrax::Pid::Configuration]
      def configure
        yield configuration
      end

      # @param key [String, Symbol]
      # @return [Hyrax::Pid::ServiceDefinition]
      def service_definition(key)
        SERVICES.fetch(key.to_s) { raise Error, "Unknown PID service #{key.inspect}" }
      end
    end
  end
end

# Skipped outside Rails so the core specs run without booting an app. The
# engine registers :doi, since its minter is built from per-tenant settings.
require_relative "pid/engine" if defined?(Rails::Engine)
