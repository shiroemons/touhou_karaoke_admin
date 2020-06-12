class CreateSongWithJoysoundUtasukis < ActiveRecord::Migration[6.0]
  def change
    create_table :song_with_joysound_utasukis, id: :uuid do |t|
      t.references :song, type: :uuid, null: false, foreign_key: true
      t.date :delivery_deadline_date, null: false
      t.string :url, null: false

      t.timestamps
    end
  end
end
