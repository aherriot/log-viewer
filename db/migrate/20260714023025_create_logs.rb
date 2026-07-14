class CreateLogs < ActiveRecord::Migration[8.1]
  def change
    # TODO(you): create a native Postgres enum type named :log_status with
    # three values: "ok", "client_error", "server_error"
    # (hint: the method is `create_enum`, takes a name and an array of strings)
    create_enum :log_status, %w[ok client_error server_error]

    create_table :logs do |t|
      # TODO(you): add the following columns, in order:
      # level       — string, not null            (debug/info/warn/error from LogGenerator)
      # status      — the :log_status enum you created above, not null
      #               (hint: t.enum :status, enum_type: :log_status, null: false)
      # http_status — integer, not null            (raw HTTP code, e.g. 200/404/500)
      # user_id     — bigint, not null
      # message     — text, not null
      # ip          — inet
      # metadata    — jsonb, not null, default: {}
      # created_at  — datetime, not null           (becomes timestamptz via the
      #               adapter-wide initializer — do NOT use t.timestamps, we only
      #               want created_at, not updated_at)

      t.string :level, null: false
      t.enum :status, enum_type: :log_status, null: false
      t.integer :http_status, null: false
      t.bigint :user_id, null: false
      t.text :message, null: false
      t.inet :ip
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
