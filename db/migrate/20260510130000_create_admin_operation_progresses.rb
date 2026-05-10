class CreateAdminOperationProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_operation_progresses, id: :uuid do |t|
      t.string :state, null: false
      t.integer :percentage, null: false, default: 0
      t.string :status, null: false
      t.string :label, null: false
      t.text :detail
      t.integer :current
      t.integer :total

      t.timestamps
    end
  end
end
