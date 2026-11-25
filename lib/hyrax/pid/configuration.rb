# frozen_string_literal: true

module Hyrax
  module Pid
    # Code-level settings set once by the host application via
    # Hyrax::Pid.configure. Credentials aren't here: admins enter them per
    # tenant on the PID services settings page (Hyrax::Pid::Service).
    class Configuration
      class DataCite
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

        # @!attribute solr_field
        #   @return [String] the Solr field a work's DOI is indexed in, read by
        #     the show-page buttons to tell "Mint" from "Update" without
        #     loading the work. Defaults to "doi_ssi".
        attr_accessor :solr_field

        def initialize
          @field_mapping = {}
          @solr_field = "doi_ssi"
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
