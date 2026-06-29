class MakeDamArtistUrlsUrlUnique < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_dam_artist_urls_on_url'.freeze

  def up
    raise_if_duplicate_urls_exist!
    remove_index :dam_artist_urls, name: INDEX_NAME, if_exists: true
    add_index :dam_artist_urls, :url, unique: true, name: INDEX_NAME
  end

  def down
    remove_index :dam_artist_urls, name: INDEX_NAME, if_exists: true
    add_index :dam_artist_urls, :url, name: INDEX_NAME
  end

  private

  def raise_if_duplicate_urls_exist!
    duplicate = connection.select_one(<<~SQL.squish)
      SELECT url, COUNT(*) AS duplicate_count
      FROM #{connection.quote_table_name(:dam_artist_urls)}
      GROUP BY url
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    return if duplicate.blank?

    raise ActiveRecord::IrreversibleMigration,
          "dam_artist_urls has duplicate url=#{duplicate.fetch('url').inspect} (duplicate_count=#{duplicate.fetch('duplicate_count')}). Run make data-duplicate-report and clean data before adding the unique index."
  end
end
