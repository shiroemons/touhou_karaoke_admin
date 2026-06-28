class AddIndexToAdminOperationProgressesUpdatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :admin_operation_progresses, :updated_at, if_not_exists: true
  end
end
