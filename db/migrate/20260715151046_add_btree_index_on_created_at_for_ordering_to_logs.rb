class AddBtreeIndexOnCreatedAtForOrderingToLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Complements the BRIN index on the same column: BRIN handles large
    # range-filter queries with a tiny footprint, but can't provide
    # pre-sorted access. This B-tree serves "most recent N" (ORDER BY
    # created_at DESC LIMIT n) via an Index Scan Backward, avoiding a
    # full-table sort.
    add_index :logs, :created_at,
      order: { created_at: :desc },
      name: "index_logs_on_created_at_btree",
      algorithm: :concurrently
  end
end
