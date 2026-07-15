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

ActiveRecord::Schema[8.1].define(version: 2026_07_15_002818) do
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
    t.enum "status", null: false, enum_type: "log_status"
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_logs_on_created_at", using: :brin
  end
end
