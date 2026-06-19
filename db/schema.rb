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

ActiveRecord::Schema[8.1].define(version: 2026_06_19_151634) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "collaborations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "request_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["request_id"], name: "index_collaborations_on_request_id"
    t.index ["user_id", "request_id"], name: "index_collaborations_on_user_id_and_request_id", unique: true
    t.index ["user_id"], name: "index_collaborations_on_user_id"
  end

  create_table "requests", force: :cascade do |t|
    t.uuid "auth_bypass_id", null: false
    t.datetime "created_at", null: false
    t.json "current_content", null: false
    t.datetime "deadline"
    t.uuid "draft_auth_bypass_id"
    t.uuid "draft_content_id"
    t.string "draft_slug"
    t.json "previous_content"
    t.string "reason_for_change"
    t.string "requester_email", null: false
    t.string "requester_name", null: false
    t.string "source_app", null: false
    t.string "source_id", null: false
    t.string "source_title"
    t.string "source_url"
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_requests_on_created_at"
    t.index ["source_app", "source_id", "created_at"], name: "index_requests_on_source_app_id_source_id_and_created_at", unique: true
  end

  create_table "responses", force: :cascade do |t|
    t.boolean "accepted"
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "request_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["request_id"], name: "index_responses_on_request_id", unique: true
    t.index ["user_id"], name: "index_responses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "disabled", default: false
    t.string "email"
    t.string "name"
    t.string "organisation_content_id"
    t.string "organisation_slug"
    t.text "permissions"
    t.string "uid"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "collaborations", "requests", on_delete: :restrict
  add_foreign_key "collaborations", "users", on_delete: :restrict
  add_foreign_key "responses", "requests", on_delete: :restrict
  add_foreign_key "responses", "users", on_delete: :restrict
end
