# frozen_string_literal: true

module Hyrax
  module Pid
    # Abstract base class every PID-minting service adapter subclasses
    # (e.g. Hyrax::Pid::DataCite::Minter, Hyrax::Pid::Crossref::Minter,
    # Hyrax::Pid::Raid::Minter). Kept deliberately small: lifecycle
    # transitions, relations, and other service-specific behavior belong
    # on the subclass, not here.
    class Minter
      # @param metadata [Hash] adapter-specific metadata payload; each
      #   subclass defines what it expects (e.g. a DataCite resource-type
      #   hash, a RAiD project record).
      # @return [Hyrax::Pid::Identifier]
      def mint(metadata:)
        raise NotImplementedError
      end

      # @param identifier [Hyrax::Pid::Identifier, String]
      # @param metadata [Hash]
      # @return [Hyrax::Pid::Identifier]
      def update(identifier:, metadata:)
        raise NotImplementedError
      end

      # @param identifier [Hyrax::Pid::Identifier, String]
      # @return [Hyrax::Pid::Identifier]
      def find(identifier:)
        raise NotImplementedError
      end

      # @return [Symbol] e.g. :doi, :handle, :ark
      def identifier_type
        raise NotImplementedError
      end
    end
  end
end
