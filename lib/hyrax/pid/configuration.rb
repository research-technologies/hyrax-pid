# frozen_string_literal: true

module Hyrax
  module Pid
    # Holds per-service settings (credentials, sandbox vs. production,
    # etc.) so a host application can configure a service once, via
    # Hyrax::Pid.configure, and have its Minter built lazily from that
    # configuration whenever the Registry resolves it.
    class Configuration
      # Settings for Hyrax::Pid::DataCite::Minter.
      class DataCite
        attr_accessor :prefix, :username, :password, :sandbox

        # @!attribute client
        #   @return [#call, nil] overrides the Minter's default Net::HTTP
        #     client, e.g. with a fake/stub for a demo or test environment.
        attr_accessor :client

        # @!attribute field_mapping
        #   @return [Hash{Symbol=>Symbol,String,#call}] maps the DataCite
        #     fields in Hyrax::Pid::DataCite::MetadataMapper::REQUIRED_FIELDS
        #     to how to read them off a work -- a method/attribute name, or a
        #     callable(work). Set by the host app since field names (and
        #     whether they're flexible-schema) vary per app.
        attr_accessor :field_mapping

        def initialize
          @sandbox = false
          @field_mapping = {}
        end

        # @return [Hyrax::Pid::DataCite::Minter]
        def minter
          Hyrax::Pid::DataCite::Minter.new(prefix: prefix, username: username, password: password, sandbox: sandbox, client: client)
        end

        # @return [Hyrax::Pid::DataCite::MetadataMapper]
        def metadata_mapper
          Hyrax::Pid::DataCite::MetadataMapper.new(mapping: field_mapping)
        end
      end

      attr_reader :data_cite

      def initialize
        @data_cite = DataCite.new
      end
    end
  end
end
