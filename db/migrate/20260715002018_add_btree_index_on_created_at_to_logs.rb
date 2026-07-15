class AddBtreeIndexOnCreatedAtToLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :logs, :created_at
  end
end
