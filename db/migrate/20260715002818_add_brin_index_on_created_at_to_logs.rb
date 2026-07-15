class AddBrinIndexOnCreatedAtToLogs < ActiveRecord::Migration[8.1]
  def change
    remove_index :logs, :created_at
    add_index :logs, :created_at, using: :brin
  end
end
