class AddUniqueIndexesToSongIdentity < ActiveRecord::Migration[8.1]
  SONG_INDEX_NAME = 'index_songs_on_karaoke_type_and_url_and_title'.freeze
  SONG_INDEX_WHERE = "url <> ''".freeze
  UTASUKI_SONG_INDEX_NAME = 'index_song_with_joysound_utasukis_on_song_id'.freeze
  UTASUKI_URL_INDEX_NAME = 'index_song_with_joysound_utasukis_on_url'.freeze

  def up
    raise_if_duplicate_songs_exist!
    raise_if_duplicate_utasuki_details_exist!

    remove_index :songs, name: SONG_INDEX_NAME, if_exists: true
    add_index :songs, %i[karaoke_type url title], unique: true, name: SONG_INDEX_NAME, where: SONG_INDEX_WHERE

    remove_index :song_with_joysound_utasukis, name: UTASUKI_SONG_INDEX_NAME, if_exists: true
    add_index :song_with_joysound_utasukis, :song_id, unique: true, name: UTASUKI_SONG_INDEX_NAME
    add_index :song_with_joysound_utasukis, :url, unique: true, name: UTASUKI_URL_INDEX_NAME
  end

  def down
    remove_index :song_with_joysound_utasukis, name: UTASUKI_URL_INDEX_NAME, if_exists: true
    remove_index :song_with_joysound_utasukis, name: UTASUKI_SONG_INDEX_NAME, if_exists: true
    add_index :song_with_joysound_utasukis, :song_id, name: UTASUKI_SONG_INDEX_NAME

    remove_index :songs, name: SONG_INDEX_NAME, if_exists: true
    add_index :songs, %i[karaoke_type url title], name: SONG_INDEX_NAME
  end

  private

  def raise_if_duplicate_songs_exist!
    duplicate = connection.select_one(<<~SQL.squish)
      SELECT karaoke_type, url, title, COUNT(*) AS duplicate_count
      FROM songs
      WHERE url <> ''
      GROUP BY karaoke_type, url, title
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    return if duplicate.blank?

    raise ActiveRecord::IrreversibleMigration,
          "songs has duplicate identity=#{duplicate.slice('karaoke_type', 'url', 'title').inspect} " \
          "(duplicate_count=#{duplicate.fetch('duplicate_count')}). Run the duplicate reconciliation first."
  end

  def raise_if_duplicate_utasuki_details_exist!
    duplicate = connection.select_one(<<~SQL.squish)
      SELECT song_id, COUNT(*) AS duplicate_count
      FROM song_with_joysound_utasukis
      GROUP BY song_id
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    if duplicate.present?
      raise ActiveRecord::IrreversibleMigration,
            "song_with_joysound_utasukis has duplicate song_id=#{duplicate.fetch('song_id').inspect} " \
            "(duplicate_count=#{duplicate.fetch('duplicate_count')}). Clean the data first."
    end

    duplicate = connection.select_one(<<~SQL.squish)
      SELECT url, COUNT(*) AS duplicate_count
      FROM song_with_joysound_utasukis
      GROUP BY url
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    return if duplicate.blank?

    raise ActiveRecord::IrreversibleMigration,
          "song_with_joysound_utasukis has duplicate url=#{duplicate.fetch('url').inspect} " \
          "(duplicate_count=#{duplicate.fetch('duplicate_count')}). Clean the data first."
  end
end
