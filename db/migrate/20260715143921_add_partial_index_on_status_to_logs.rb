class AddPartialIndexOnStatusToLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :logs, :status, where: "status = 'server_error'", name: "index_logs_on_status_server_error"
  end
end
