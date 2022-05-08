class AddSpotifyUrlToSongs < ActiveRecord::Migration[7.0]
  def change
    add_column :songs, :spotify_url, :string, null: false, default: ""
  end
end
