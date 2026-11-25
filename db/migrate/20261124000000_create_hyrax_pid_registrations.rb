# frozen_string_literal: true

# What the PID service last told us about each work's identifier (e.g. a
# DataCite DOI's draft/registered/findable state), so show pages can offer the
# right action without calling the service.
class CreateHyraxPidRegistrations < ActiveRecord::Migration[7.1]
  def change
    create_table :hyrax_pid_registrations do |t|
      t.string :resource_id, null: false
      t.string :identifier_type, null: false
      t.string :identifier, null: false
      t.string :state
      t.timestamps
    end
    add_index :hyrax_pid_registrations, %i[resource_id identifier_type], unique: true
  end
end
