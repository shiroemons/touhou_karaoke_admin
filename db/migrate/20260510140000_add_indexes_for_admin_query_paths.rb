class AddIndexesForAdminQueryPaths < ActiveRecord::Migration[8.1]
  def change
    add_index :dam_artist_urls, :url, if_not_exists: true
    add_index :dam_songs, :created_at, if_not_exists: true
    add_index :dam_songs, :url, if_not_exists: true

    add_index :display_artists, :created_at, if_not_exists: true
    add_index :display_artists, %i[karaoke_type name], if_not_exists: true
    add_index :display_artists, %i[karaoke_type url name_reading], if_not_exists: true

    add_index :joysound_music_posts, :created_at, if_not_exists: true
    add_index :joysound_music_posts, :delivery_deadline_on, if_not_exists: true
    add_index :joysound_music_posts, :joysound_url, if_not_exists: true
    add_index :joysound_music_posts, :url, if_not_exists: true

    add_index :joysound_songs, :created_at, if_not_exists: true
    add_index :joysound_songs, :url, if_not_exists: true

    add_index :karaoke_delivery_models, :order, if_not_exists: true

    add_index :songs, :created_at, if_not_exists: true
    add_index :songs, %i[karaoke_type created_at], if_not_exists: true
    add_index :songs, %i[karaoke_type url title], if_not_exists: true
  end
end
