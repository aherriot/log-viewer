# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_15_152653) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "log_status", ["ok", "client_error", "server_error"]

  create_table "logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "http_status", null: false
    t.inet "ip"
    t.string "level", null: false
    t.text "message", null: false
    t.jsonb "metadata", default: {}, null: false
    t.virtual "search_vector", type: :tsvector, as: "to_tsvector('english'::regconfig, message)", stored: true
    t.enum "status", null: false, enum_type: "log_status"
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_logs_on_created_at", using: :brin
    t.index ["created_at"], name: "index_logs_on_created_at_btree", order: :desc
    t.index ["ip"], name: "index_logs_on_ip_gist", opclass: :inet_ops, using: :gist
    t.index ["level"], name: "index_logs_on_level"
    t.index ["metadata"], name: "index_logs_on_metadata", using: :gin
    t.index ["search_vector"], name: "index_logs_on_search_vector", using: :gin
    t.index ["status"], name: "index_logs_on_status_server_error", where: "(status = 'server_error'::log_status)"
    t.index ["user_id", "status"], name: "index_logs_on_user_id_status_covering", include: ["created_at"]
  end
end
