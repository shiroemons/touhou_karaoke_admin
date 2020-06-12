class CreateJoysoundSongs < ActiveRecord::Migration[6.0]
  def change
    create_table :joysound_songs, id: :uuid do |t|
      t.string :display_title, null: false
      t.string :url, null: false
      t.boolean :smartphone_service_enabled, null: false, default: false
      t.boolean :home_karaoke_enabled, null: false, default: false

      t.timestamps
    end
  end
end
