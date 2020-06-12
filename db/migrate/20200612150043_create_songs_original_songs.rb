class CreateSongsOriginalSongs < ActiveRecord::Migration[6.0]
  def change
    create_table :songs_original_songs, id: :uuid do |t|
      t.references :song, type: :uuid, null: false, foreign_key: true
      t.string :original_song_code, null: false
      t.index :original_song_code

      t.timestamps
    end
  end
end
