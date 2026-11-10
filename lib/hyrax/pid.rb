# frozen_string_literal: true

require_relative "pid/version"
require_relative "pid/error"
require_relative "pid/identifier"
require_relative "pid/minter"
require_relative "pid/registry"
require_relative "pid/configuration"
require_relative "pid/data_cite/client"
require_relative "pid/data_cite/metadata_mapper"
require_relative "pid/data_cite/minter"

module Hyrax
  module Pid
    class << self
      # @return [Hyrax::Pid::Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # @yieldparam configuration [Hyrax::Pid::Configuration]
      def configure
        yield configuration
      end
    end
  end
end

Hyrax::Pid::Registry.register(:doi, -> { Hyrax::Pid.configuration.data_cite.minter })
