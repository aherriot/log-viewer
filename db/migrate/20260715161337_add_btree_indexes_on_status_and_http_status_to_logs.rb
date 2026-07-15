class AddBtreeIndexesOnStatusAndHttpStatusToLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # A full index on status makes the Phase 7 partial index redundant: it
    # serves the same status = 'server_error' filter just as well, plus
    # every other status value, plus ORDER BY status (which the partial
    # index, scoped to one value, never could).
    remove_index :logs, name: "index_logs_on_status_server_error", algorithm: :concurrently
    add_index :logs, :status, algorithm: :concurrently
    add_index :logs, :http_status, algorithm: :concurrently
  end
end
