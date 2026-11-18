# frozen_string_literal: true

class CreateHyraxPidServices < ActiveRecord::Migration[7.1]
  def change
    create_table :hyrax_pid_services do |t|
      t.string :service, null: false
      t.json :settings, null: false, default: {}
      # Encrypted JSON (Active Record encryption), so text rather than json.
      t.text :secrets
      t.timestamps
    end
    add_index :hyrax_pid_services, :service, unique: true
  end
end
