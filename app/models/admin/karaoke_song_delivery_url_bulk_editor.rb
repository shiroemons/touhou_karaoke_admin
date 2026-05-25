require 'csv'

module Admin
  class KaraokeSongDeliveryUrlBulkEditor
    URL_COLUMNS = %w[
      youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url
    ].freeze
    COLUMNS = %w[
      id karaoke_type display_artist_name title original_songs
    ].concat(URL_COLUMNS).freeze

    Result = Data.define(:updated_count, :skipped_count, :errors)
    PreviewResult = Data.define(:checked_count, :errors, :rows)

    def initialize(actor_name:)
      @actor_name = actor_name
      @song_resource = ResourceRegistry.fetch(:song)
    end

    def update_from_form_rows(row_params)
      update_rows(normalized_form_rows(row_params))
    end

    def update_from_tsv(tsv)
      rows = parse_tsv_rows(tsv)
      return rows if rows.is_a?(Result)

      update_rows(rows)
    rescue CSV::MalformedCSVError => e
      Result.new(updated_count: 0, skipped_count: 0, errors: ["TSVを読み取れませんでした: #{e.message}"])
    end

    def preview_from_form_rows(row_params)
      preview_rows(normalized_form_rows(row_params), include_unchanged: false)
    end

    def preview_from_tsv(tsv)
      rows = parse_tsv_rows(tsv)
      return PreviewResult.new(checked_count: 0, errors: rows.errors, rows: []) if rows.is_a?(Result)

      preview_rows(rows, include_unchanged: true)
    rescue CSV::MalformedCSVError => e
      PreviewResult.new(checked_count: 0, errors: ["TSVを読み取れませんでした: #{e.message}"], rows: [])
    end

    private

    attr_reader :actor_name, :song_resource

    def normalized_form_rows(row_params)
      row_params.to_h.map do |song_id, attributes|
        attributes.to_h.stringify_keys.slice(*URL_COLUMNS).merge('id' => song_id)
      end
    end

    def parse_tsv_rows(tsv)
      table = CSV.parse(tsv.to_s, col_sep: "\t", headers: true, converters: nil, liberal_parsing: true)
      missing_columns = COLUMNS - table.headers.compact
      return Result.new(updated_count: 0, skipped_count: 0, errors: ["TSVの列が不足しています: #{missing_columns.join(', ')}"]) if missing_columns.present?

      table.map { |row| row.to_h.slice(*COLUMNS) }
    end

    def update_rows(rows)
      updates, errors = build_updates(rows)
      return Result.new(updated_count: 0, skipped_count: rows.size, errors:) if errors.present?

      updated_count = 0
      skipped_count = 0

      Song.transaction do
        updates.each do |update|
          if update_applied?(update)
            updated_count += 1
          else
            skipped_count += 1
          end
        end
      end

      Result.new(updated_count:, skipped_count:, errors: [])
    end

    def preview_rows(rows, include_unchanged:)
      updates, errors = build_updates(rows)
      preview_items = updates.filter_map do |update|
        item = preview_item(update)
        item if include_unchanged || item.fetch(:changed_url_columns).present?
      end

      PreviewResult.new(checked_count: preview_items.size, errors:, rows: preview_items)
    end

    def build_updates(rows)
      errors = []
      updates = rows.filter_map.with_index(2) do |row, row_number|
        song_id = row['id'].to_s
        next if song_id.blank?

        song = Song.includes(:display_artist, original_songs: :original).find_by(id: song_id)
        unless song
          errors << "#{row_number}行目: 楽曲ID #{song_id} が見つかりません。"
          next
        end

        {
          song:,
          attributes: normalized_url_attributes(row)
        }
      end

      [updates, errors]
    end

    def preview_item(update)
      song = update.fetch(:song)
      attributes = update.fetch(:attributes)
      current_attributes = URL_COLUMNS.index_with { |column| song.public_send(column).to_s }
      changed_url_columns = URL_COLUMNS.reject { |column| current_attributes[column] == attributes[column].to_s }

      {
        song:,
        current_original_song_titles: song.original_songs.map(&:title),
        changed_url_columns:,
        url_changes: changed_url_columns.index_with do |column|
          {
            before: current_attributes[column],
            after: attributes[column].to_s
          }
        end
      }
    end

    def update_applied?(update)
      song = update.fetch(:song)
      song.assign_attributes(update.fetch(:attributes))
      return false unless song.changed?

      song.save!
      ChangeLog.record_update!(resource: song_resource, record: song, actor_name:)
      true
    end

    def normalized_url_attributes(row)
      URL_COLUMNS.index_with { |column| row[column].to_s.strip }
    end
  end
end
