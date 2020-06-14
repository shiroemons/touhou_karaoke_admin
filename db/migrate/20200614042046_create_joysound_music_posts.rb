class CreateJoysoundMusicPosts < ActiveRecord::Migration[6.0]
  def change
    create_table :joysound_music_posts, id: :uuid do |t|
      t.string :title, null: false
      t.string :artist, null: false
      t.string :producer, null: false
      t.date :delivery_deadline_on, null: false
      t.string :url, null: false

      t.timestamps
    end
  end
end
