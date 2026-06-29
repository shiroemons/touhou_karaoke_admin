# frozen_string_literal: true

module DataIntegrity
  class DuplicateImpactReporter
    DamArtistUrlImpact = Data.define(
      :url,
      :duplicate_count,
      :canonical_id,
      :duplicate_ids,
      :display_artist_count,
      :dam_song_count,
      :rows
    )

    def dam_artist_url_impacts
      duplicate_urls('dam_artist_urls', %w[url]).map do |row|
        url = row.fetch('url')
        records = DamArtistUrl.where(url:).order(:created_at, :id).to_a
        display_artist_scope = DisplayArtist.where(karaoke_type: 'DAM', url:)

        DamArtistUrlImpact.new(
          url:,
          duplicate_count: row.fetch('duplicate_count').to_i,
          canonical_id: records.first&.id,
          duplicate_ids: records.drop(1).map(&:id),
          display_artist_count: display_artist_scope.count,
          dam_song_count: DamSong.joins(:display_artist).merge(display_artist_scope).count,
          rows: records.map { |record| row_attributes(record) }
        )
      end
    end

    private

    def duplicate_urls(table, columns)
      quoted_columns = columns.map { |column| connection.quote_column_name(column) }
      connection.execute(<<~SQL.squish).to_a
        SELECT #{quoted_columns.join(', ')}, COUNT(*) AS duplicate_count
        FROM #{connection.quote_table_name(table)}
        GROUP BY #{quoted_columns.join(', ')}
        HAVING COUNT(*) > 1
        ORDER BY duplicate_count DESC
      SQL
    end

    def row_attributes(record)
      {
        id: record.id,
        created_at: record.created_at,
        updated_at: record.updated_at
      }
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
