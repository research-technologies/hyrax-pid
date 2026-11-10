# frozen_string_literal: true

module Hyrax
  module Pid
    # Plain value object returned by every Minter so callers never touch
    # a provider's raw response shape directly.
    class Identifier
      attr_reader :value, :type, :state, :raw

      # @param value [String] the identifier itself (e.g. a DOI, a Handle)
      # @param type [Symbol] e.g. :doi, :handle, :ark
      # @param state [Symbol, nil] lifecycle state if the service has one
      #   (e.g. :draft, :registered, :findable); nil otherwise
      # @param raw [Object, nil] the adapter's full provider response, kept
      #   for debugging/advanced use
      def initialize(value:, type:, state: nil, raw: nil)
        @value = value
        @type = type
        @state = state
        @raw = raw
      end

      def to_s
        value
      end
    end
  end
end
