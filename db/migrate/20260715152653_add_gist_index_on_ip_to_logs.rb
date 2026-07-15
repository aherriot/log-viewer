class AddGistIndexOnIpToLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # GiST + inet_ops supports subnet containment operators (<<, <<=, >>=),
    # unlike the metadata GIN index, which only does exact string matching
    # since jsonb has no concept of network arithmetic.
    add_index :logs, :ip, using: :gist, opclass: :inet_ops,
      name: "index_logs_on_ip_gist", algorithm: :concurrently
  end
end
