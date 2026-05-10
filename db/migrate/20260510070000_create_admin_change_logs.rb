class CreateAdminChangeLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_change_logs, id: :uuid do |t|
      t.string :resource_key, null: false
      t.string :resource_label, null: false
      t.string :record_type, null: false
      t.string :record_id, null: false
      t.string :record_title, null: false
      t.string :event, null: false
      t.jsonb :changed_fields, null: false, default: {}
      t.string :actor_name, null: false

      t.timestamps
    end

    add_index :admin_change_logs, %i[resource_key record_id created_at]
    add_index :admin_change_logs, %i[resource_key event created_at]
  end
end
