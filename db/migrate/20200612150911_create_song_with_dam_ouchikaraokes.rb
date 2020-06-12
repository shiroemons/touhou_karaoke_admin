class CreateSongWithDamOuchikaraokes < ActiveRecord::Migration[6.0]
  def change
    create_table :song_with_dam_ouchikaraokes, id: :uuid do |t|
      t.references :song, type: :uuid, null: false, foreign_key: true
      t.string :url, null: false

      t.timestamps
    end
  end
end
