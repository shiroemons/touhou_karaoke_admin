class AddYouTubeUrlToSongs < ActiveRecord::Migration[6.0]
  def change
    add_column :songs, :youtube_url, :string, null: false, default: ""
  end
end
