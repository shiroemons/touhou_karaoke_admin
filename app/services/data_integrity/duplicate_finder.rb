# frozen_string_literal: true

module DataIntegrity
  class DuplicateFinder
    Check = Data.define(:table, :columns)
    Result = Data.define(:table, :columns, :rows)

    DEFAULT_CHECKS = [
      Check.new(table: 'dam_artist_urls', columns: %w[url]),
      Check.new(table: 'dam_songs', columns: %w[url]),
      Check.new(table: 'display_artists_circles', columns: %w[display_artist_id circle_id]),
      Check.new(table: 'joysound_music_posts', columns: %w[url]),
      Check.new(table: 'joysound_songs', columns: %w[url]),
      Check.new(table: 'song_with_dam_ouchikaraokes', columns: %w[song_id]),
      Check.new(table: 'song_with_dam_ouchikaraokes', columns: %w[url]),
      Check.new(table: 'song_with_joysound_utasukis', columns: %w[song_id]),
      Check.new(table: 'song_with_joysound_utasukis', columns: %w[url]),
      Check.new(table: 'songs_original_songs', columns: %w[song_id original_song_code])
    ].freeze

    def initialize(checks: DEFAULT_CHECKS, limit: 20)
      @checks = checks
      @limit = limit
      @connection = ActiveRecord::Base.connection
    end

    def call
      checks.filter_map do |check|
        result = Result.new(table: check.table, columns: check.columns, rows: duplicate_rows(check))
        next if result.rows.blank?

        result
      end
    end

    private

    attr_reader :checks, :limit, :connection

    def duplicate_rows(check)
      quoted_columns = check.columns.map { |column| connection.quote_column_name(column) }
      select_columns = quoted_columns.join(', ')

      connection.execute(<<~SQL.squish).to_a
        SELECT #{select_columns}, COUNT(*) AS duplicate_count
        FROM #{connection.quote_table_name(check.table)}
        GROUP BY #{select_columns}
        HAVING COUNT(*) > 1
        ORDER BY duplicate_count DESC
        LIMIT #{Integer(limit)}
      SQL
    end
  end
end
