class CreateDisplayArtists < ActiveRecord::Migration[6.0]
  def change
    create_table :display_artists, id: :uuid do |t|
      t.string :name, null: false
      t.string :name_reading, null: false, default: ""
      t.string :karaoke_type, null: false
      t.string :url, null: false, default: ""

      t.timestamps
    end
  end
end
