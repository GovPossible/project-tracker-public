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

ActiveRecord::Schema[8.1].define(version: 2026_03_10_133154) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.text "details"
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_activities_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "attempt_count", default: 0, null: false
    t.jsonb "branches", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "file_urls", default: [], null: false
    t.string "honeybadger_fault_id"
    t.string "honeybadger_project_key"
    t.integer "max_attempts", default: 3, null: false
    t.jsonb "pr_urls", default: {}, null: false
    t.integer "priority", default: 2, null: false
    t.jsonb "repos", default: [], null: false
    t.integer "source", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.datetime "waiting_since"
    t.index ["honeybadger_fault_id"], name: "index_projects_on_honeybadger_fault_id", unique: true, where: "(honeybadger_fault_id IS NOT NULL)"
    t.index ["priority"], name: "index_projects_on_priority"
    t.index ["status"], name: "index_projects_on_status"
  end

  create_table "replies", force: :cascade do |t|
    t.text "body"
    t.integer "channel", null: false
    t.datetime "created_at", null: false
    t.string "from_address"
    t.jsonb "image_urls", default: [], null: false
    t.bigint "project_id", null: false
    t.boolean "read", default: false, null: false
    t.datetime "received_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "read"], name: "index_replies_on_project_id_and_read"
    t.index ["project_id"], name: "index_replies_on_project_id"
  end

  create_table "repos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "framework"
    t.string "gemset"
    t.string "github_url", null: false
    t.string "local_path"
    t.string "name", null: false
    t.string "ruby_version"
    t.text "setup_log"
    t.string "setup_status", default: "pending", null: false
    t.string "test_command"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_repos_on_name", unique: true
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
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "activities", "projects"
  add_foreign_key "replies", "projects"
  add_foreign_key "sessions", "users"
end
