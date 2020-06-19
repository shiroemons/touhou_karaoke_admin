class CreateDamSongs < ActiveRecord::Migration[6.0]
  def change
    create_table :dam_songs, id: :uuid do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.references :display_artist, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end
  end
end
