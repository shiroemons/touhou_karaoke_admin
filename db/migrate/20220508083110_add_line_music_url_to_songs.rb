class AddLineMusicUrlToSongs < ActiveRecord::Migration[7.0]
  def change
    add_column :songs, :line_music_url, :string, null: false, default: ""
  end
end
