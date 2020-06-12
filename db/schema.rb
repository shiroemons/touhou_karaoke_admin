# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_06_12_151906) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "circles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "display_artists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "name_reading", default: "", null: false
    t.string "karaoke_type", null: false
    t.string "url", default: "", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "display_artists_circles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "display_artist_id", null: false
    t.uuid "circle_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["circle_id"], name: "index_display_artists_circles_on_circle_id"
    t.index ["display_artist_id"], name: "index_display_artists_circles_on_display_artist_id"
  end

  create_table "joysound_songs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "display_title", null: false
    t.string "url", null: false
    t.boolean "smartphone_service_enabled", default: false, null: false
    t.boolean "home_karaoke_enabled", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "karaoke_delivery_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "karaoke_type", null: false
    t.integer "order", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "original_songs", primary_key: "code", id: :string, force: :cascade do |t|
    t.string "original_code", null: false
    t.string "title", null: false
    t.string "composer", default: "", null: false
    t.integer "track_number", null: false
    t.boolean "is_duplicate", default: false, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["code"], name: "index_original_songs_on_code", unique: true
    t.index ["original_code"], name: "index_original_songs_on_original_code"
  end

  create_table "originals", primary_key: "code", id: :string, force: :cascade do |t|
    t.string "title", null: false
    t.string "short_title", null: false
    t.string "original_type", null: false
    t.float "series_order", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "song_original_songs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "song_id", null: false
    t.string "original_song_code", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["original_song_code"], name: "index_song_original_songs_on_original_song_code"
    t.index ["song_id"], name: "index_song_original_songs_on_song_id"
  end

  create_table "song_with_dam_ouchikaraokes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "song_id", null: false
    t.string "url", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["song_id"], name: "index_song_with_dam_ouchikaraokes_on_song_id"
  end

  create_table "song_with_joysound_utasukis", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "song_id", null: false
    t.date "delivery_deadline_date", null: false
    t.string "url", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["song_id"], name: "index_song_with_joysound_utasukis_on_song_id"
  end

  create_table "songs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "title_reading", default: "", null: false
    t.uuid "display_artist_id", null: false
    t.string "karaoke_type", null: false
    t.string "song_number", default: "", null: false
    t.string "url", default: "", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["display_artist_id"], name: "index_songs_on_display_artist_id"
  end

  create_table "songs_karaoke_delivery_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "song_id", null: false
    t.uuid "karaoke_delivery_model_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["karaoke_delivery_model_id"], name: "idx_songs_karaoke_delivery_models_on_karaoke_delivery_model_id"
    t.index ["song_id"], name: "index_songs_karaoke_delivery_models_on_song_id"
  end

  create_table "songs_original_songs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "song_id", null: false
    t.string "original_song_code", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["original_song_code"], name: "index_songs_original_songs_on_original_song_code"
    t.index ["song_id"], name: "index_songs_original_songs_on_song_id"
  end

  add_foreign_key "display_artists_circles", "circles"
  add_foreign_key "display_artists_circles", "display_artists"
  add_foreign_key "song_original_songs", "songs"
  add_foreign_key "song_with_dam_ouchikaraokes", "songs"
  add_foreign_key "song_with_joysound_utasukis", "songs"
  add_foreign_key "songs", "display_artists"
  add_foreign_key "songs_karaoke_delivery_models", "karaoke_delivery_models"
  add_foreign_key "songs_karaoke_delivery_models", "songs"
  add_foreign_key "songs_original_songs", "songs"
end
