class AddUniqueIndexesToJoinTables < ActiveRecord::Migration[8.1]
  INDEXES = [
    {
      table: :display_artists_circles,
      columns: %i[display_artist_id circle_id],
      name: 'idx_display_artists_circles_unique_artist_circle'
    },
    {
      table: :songs_original_songs,
      columns: %i[song_id original_song_code],
      name: 'idx_songs_original_songs_unique_song_original'
    }
  ].freeze

  def up
    INDEXES.each do |definition|
      raise_if_duplicates_exist!(definition)
      add_index definition.fetch(:table),
                definition.fetch(:columns),
                unique: true,
                name: definition.fetch(:name),
                if_not_exists: true
    end
  end

  def down
    INDEXES.reverse_each do |definition|
      remove_index definition.fetch(:table), name: definition.fetch(:name), if_exists: true
    end
  end

  private

  def raise_if_duplicates_exist!(definition)
    table = definition.fetch(:table)
    columns = definition.fetch(:columns)
    quoted_columns = columns.map { |column| connection.quote_column_name(column) }
    duplicate = connection.select_one(<<~SQL.squish)
      SELECT #{quoted_columns.join(', ')}, COUNT(*) AS duplicate_count
      FROM #{connection.quote_table_name(table)}
      GROUP BY #{quoted_columns.join(', ')}
      HAVING COUNT(*) > 1
      LIMIT 1
    SQL
    return if duplicate.blank?

    values = columns.map { |column| "#{column}=#{duplicate.fetch(column.to_s)}" }.join(', ')
    raise ActiveRecord::IrreversibleMigration,
          "#{table} has duplicate rows for #{columns.join(', ')} (#{values}, duplicate_count=#{duplicate.fetch('duplicate_count')}). Run make data-duplicate-impact-report and clean data before adding the unique index."
  end
end
