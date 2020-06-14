class AddJoysoundUrlToJoysoundMusicPost < ActiveRecord::Migration[6.0]
  def change
    add_column :joysound_music_posts, :joysound_url, :string, null: false, default: ""
  end
end
