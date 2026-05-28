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

ActiveRecord::Schema[8.1].define(version: 2026_05_28_090015) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "camp_sessions", force: :cascade do |t|
    t.bigint "camp_id", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.string "room"
    t.datetime "starts_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["camp_id", "starts_at"], name: "index_camp_sessions_on_camp_id_and_starts_at"
    t.index ["camp_id"], name: "index_camp_sessions_on_camp_id"
  end

  create_table "camps", force: :cascade do |t|
    t.text "brief"
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.bigint "organizer_id", null: false
    t.date "start_date", null: false
    t.string "target_artist"
    t.datetime "updated_at", null: false
    t.index ["organizer_id", "start_date"], name: "index_camps_on_organizer_id_and_start_date"
    t.index ["organizer_id"], name: "index_camps_on_organizer_id"
  end

  create_table "magic_links", force: :cascade do |t|
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "requested_ip"
    t.string "requested_user_agent"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_magic_links_on_expires_at"
    t.index ["token_digest"], name: "index_magic_links_on_token_digest", unique: true
    t.index ["user_id"], name: "index_magic_links_on_user_id"
  end

  create_table "session_assignments", force: :cascade do |t|
    t.bigint "camp_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "writer_id", null: false
    t.index ["camp_session_id", "writer_id"], name: "index_session_assignments_unique_per_session", unique: true
    t.index ["camp_session_id"], name: "index_session_assignments_on_camp_session_id"
    t.index ["writer_id"], name: "index_session_assignments_on_writer_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "role", default: "writer", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
  end

  create_table "writer_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "pro_affiliation"
    t.string "pronouns"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_writer_profiles_on_user_id", unique: true
  end

  add_foreign_key "camp_sessions", "camps"
  add_foreign_key "camps", "users", column: "organizer_id"
  add_foreign_key "magic_links", "users"
  add_foreign_key "session_assignments", "camp_sessions"
  add_foreign_key "session_assignments", "users", column: "writer_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "writer_profiles", "users"
end
