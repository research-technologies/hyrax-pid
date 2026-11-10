# frozen_string_literal: true

module Hyrax
  module Pid
    module DataCite
      # Builds the minimum DataCite attributes hash a draft DOI needs
      # (titles, creators, publisher, publicationYear, types) from a work,
      # using a host-configured field mapping -- see
      # Hyrax::Pid::Configuration::DataCite#field_mapping. Required fields
      # per https://datacite-metadata-schema.readthedocs.io/en/4.7/properties/overview/
      # are Identifier (supplied by the Minter itself), Creator, Title,
      # Publisher, PublicationYear, and ResourceType.
      #
      # A mapping value is one of:
      #   - a Symbol: read as a method/attribute on the work (first element
      #     is used if the result is an Array, since Hyrax/Valkyrie metadata
      #     fields are typically multi-valued)
      #   - a callable (responds to #call): called with the work, so a host
      #     app can derive a value or read a flexible-schema field that
      #     varies per work type/admin set
      #   - anything else: used as a literal constant value (e.g. a fixed
      #     publisher name or resourceTypeGeneral)
      #
      # :creator is special-cased to allow more than one DataCite Creator and
      # richer sub-fields (nameType, nameIdentifiers, affiliation): if its
      # mapping resolves to an Array of Hashes, each Hash is used verbatim as
      # a DataCite creator object instead of being collapsed to a single
      # `{name: ...}` (which is what happens for a plain String/Array<String>
      # result, for hosts that don't need more than a flat name).
      #
      # A host may also map any of OPTIONAL_FIELDS (e.g. :related_items, for
      # DataCite's optional relatedItem property) the same way; unlike a
      # required field, these are simply left out of #build's result if
      # unmapped or blank, rather than raising.
      class MetadataMapper
        REQUIRED_FIELDS = %i[title creator publisher publication_year resource_type_general].freeze

        # Optional DataCite attributes a host may additionally map, keyed by
        # the field name the host configures -> the actual DataCite JSON
        # attribute name. Included in #build's result only when mapped AND
        # the mapping resolves to a non-blank value for this work; unlike
        # REQUIRED_FIELDS, an unmapped or blank optional field is silently
        # left out rather than raising.
        OPTIONAL_FIELDS = {related_items: :relatedItems}.freeze

        # @param mapping [Hash{Symbol=>Symbol,String,#call}] keyed by the
        #   fields in REQUIRED_FIELDS, plus any of OPTIONAL_FIELDS a host
        #   wants to supply
        def initialize(mapping:)
          @mapping = mapping
        end

        # @param work [#id]
        # @return [Hash] DataCite attributes suitable for Minter#mint/#update
        # @raise [Hyrax::Pid::Error] if a required field has no mapping, or
        #   resolves to a blank value for this work
        def build(work)
          values = REQUIRED_FIELDS.each_with_object({}) { |field, hash| hash[field] = resolve(field, work) }
          missing = values.select { |_, value| blank?(value) }.keys
          if missing.any?
            raise Hyrax::Pid::Error, "Missing required DataCite metadata for #{work.class} (#{work.id}): #{missing.join(', ')}"
          end

          {
            titles: [{title: values[:title]}],
            creators: creators_for(values[:creator]),
            publisher: values[:publisher],
            publicationYear: values[:publication_year],
            types: {resourceTypeGeneral: values[:resource_type_general]}
          }.merge(optional_attributes(work))
        end

        private

        def optional_attributes(work)
          OPTIONAL_FIELDS.each_with_object({}) do |(field, key), hash|
            next unless @mapping.key?(field)

            value = resolve_source(@mapping[field], work)
            hash[key] = value unless blank?(value)
          end
        end

        def creators_for(value)
          return value if value.is_a?(Array) && value.all? { |item| item.is_a?(Hash) }

          [{name: value}]
        end

        def resolve(field, work)
          raise Hyrax::Pid::Error, "No DataCite field mapping configured for :#{field}" unless @mapping.key?(field)

          collapse(resolve_source(@mapping[field], work))
        end

        def resolve_source(source, work)
          case source
          when Symbol then work.public_send(source)
          else source.respond_to?(:call) ? source.call(work) : source
          end
        end

        # Collapses a plain Array (e.g. a multi-valued Hyrax/Valkyrie field)
        # to its first element, but leaves an Array of Hashes (a richly-mapped
        # :creator result -- see class docs) alone.
        def collapse(value)
          return value if value.is_a?(Array) && value.any? && value.all? { |item| item.is_a?(Hash) }

          value.is_a?(Array) ? value.first : value
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
