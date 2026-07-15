class AddCoveringIndexOnUserIdStatusToLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :logs, [ :user_id, :status ], include: [ :created_at ], name: "index_logs_on_user_id_status_covering"
  end
end
