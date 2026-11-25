# frozen_string_literal: true

module Hyrax
  module Pid
    # The last known state of one work's identifier of one type, as reported by
    # the PID service on mint/update/publish. A cache, not the source of truth:
    # the service is. Identifiers minted before this table existed have no row.
    class Registration < ::ActiveRecord::Base
      validates :resource_id, :identifier_type, :identifier, presence: true

      class << self
        # @param resource_id [#to_s]
        # @param identifier [Hyrax::Pid::Identifier]
        def record!(resource_id:, identifier:)
          return if identifier.value.to_s.empty?

          row = find_or_initialize_by(resource_id: resource_id.to_s, identifier_type: identifier.type.to_s)
          row.update!(identifier: identifier.value, state: identifier.state&.to_s)
          row
        end

        # @return [Hyrax::Pid::Registration, nil]
        def for(resource_id, type: :doi)
          find_by(resource_id: resource_id.to_s, identifier_type: type.to_s)
        end
      end
    end
  end
end
