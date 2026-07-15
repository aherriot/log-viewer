class AddGinIndexOnMetadataToLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :logs, :metadata, using: :gin
  end
end
