class AddConcurrentIndexOnLevelToLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :logs, :level, algorithm: :concurrently
  end
end
