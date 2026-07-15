class AddSearchVectorToLogs < ActiveRecord::Migration[8.1]
  def change
    
    add_column :logs, :search_vector, :tsvector,as: "to_tsvector('english', message)", stored: true

    add_index :logs, :search_vector, using: :gin
  end
end
