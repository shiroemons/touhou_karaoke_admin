class CreateDisplayArtistsCircles < ActiveRecord::Migration[6.0]
  def change
    create_table :display_artists_circles, id: :uuid do |t|
      t.references :display_artist, type: :uuid, null: false, foreign_key: true
      t.references :circle, type: :uuid, null: false, foreign_key: true

      t.timestamps
    end
  end
end
