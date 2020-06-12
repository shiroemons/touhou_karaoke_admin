class CreateSongs < ActiveRecord::Migration[6.0]
  def change
    create_table :songs, id: :uuid do |t|
      t.string :title, null: false
      t.string :title_reading, null: false, default: ""
      t.references :display_artist, type: :uuid, null: false, foreign_key: true
      t.string :karaoke_type, null: false
      t.string :song_number, null: false, default: ""
      t.string :url, null: false, default: ""

      t.timestamps
    end
  end
end
