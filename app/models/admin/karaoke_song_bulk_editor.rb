require 'csv'

module Admin
  class KaraokeSongBulkEditor
    COLUMNS = OperationRunner::SONG_EXPORT_COLUMNS
    URL_COLUMNS = %w[
      youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url
    ].freeze
    EDITABLE_COLUMNS = ['original_songs', *URL_COLUMNS].freeze

    Result = Data.define(:updated_count, :skipped_count, :errors)
    PreviewResult = Data.define(:checked_count, :errors, :rows)

    def self.normalize_original_song_title(title)
      title.to_s.unicode_normalize(:nfkc)
           .tr('〜∼', '~')
           .gsub(/[[:space:]]+/, ' ')
           .gsub(/\s*~\s*/, ' ~ ')
           .strip
    end

    def self.search_original_song_options(query, limit: 20)
      normalized_query = normalize_original_song_title(query)
      songs = OriginalSong.non_duplicated.includes(:original).order(:title).to_a
      songs = songs.select { |song| normalize_original_song_title(song.title).include?(normalized_query) } if normalized_query.present?

      songs.first(limit)
    end

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

    def resolve_original_song_titles(text)
      errors = []
      entries = resolve_original_song_entries(text.to_s, 1, errors)
      original_songs = entries.filter_map { |entry| entry.fetch(:original_song) }

      {
        titles: errors.present? ? [] : original_songs.map(&:title),
        items: entries.map { |entry| original_song_resolution_item(entry) },
        errors: errors.map { |error| error.sub(/\A1行目: /, '') }
      }
    end

    private

    attr_reader :actor_name, :song_resource

    def normalized_form_rows(row_params)
      row_params.to_h.map do |song_id, attributes|
        attributes.to_h.stringify_keys.slice(*EDITABLE_COLUMNS).merge('id' => song_id)
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
        item if include_unchanged || item.fetch(:changed)
      end

      PreviewResult.new(checked_count: preview_items.size, errors:, rows: preview_items)
    end

    def build_updates(rows)
      errors = []
      updates = rows.filter_map.with_index(2) do |row, row_number|
        song_id = row['id'].to_s
        next if song_id.blank?

        song = Song.includes(:original_songs).find_by(id: song_id)
        unless song
          errors << "#{row_number}行目: 楽曲ID #{song_id} が見つかりません。"
          next
        end

        original_songs = resolve_original_songs(row['original_songs'].to_s, row_number, errors)
        {
          song:,
          original_songs:,
          attributes: normalized_url_attributes(row)
        }
      end

      [updates, errors]
    end

    def preview_item(update)
      song = update.fetch(:song)
      attributes = update.fetch(:attributes)
      current_attributes = URL_COLUMNS.index_with { |column| song.public_send(column).to_s }
      original_songs = update.fetch(:original_songs)

      {
        song:,
        original_songs: original_songs.map { |original_song| original_song_preview(original_song) },
        current_original_song_titles: song.original_songs.map(&:title),
        changed_url_columns: URL_COLUMNS.reject { |column| current_attributes[column] == attributes[column].to_s },
        changed: preview_changed?(song, original_songs, current_attributes, attributes)
      }
    end

    def preview_changed?(song, original_songs, current_attributes, attributes)
      song.original_songs.map(&:code).sort != original_songs.map(&:code).sort ||
        URL_COLUMNS.any? { |column| current_attributes[column] != attributes[column].to_s }
    end

    def original_song_preview(original_song)
      {
        code: original_song.code,
        title: original_song.title,
        original_short_title: original_song.original_short_title,
        label: "[#{original_song.original_short_title}] #{original_song.title}"
      }
    end

    def update_applied?(update)
      song = update.fetch(:song)
      before_original_song_codes = song.original_songs.map(&:code).sort
      song.original_songs = update.fetch(:original_songs)
      song.assign_attributes(update.fetch(:attributes))
      original_songs_changed = before_original_song_codes != song.original_songs.map(&:code).sort
      return false unless original_songs_changed || song.changed?

      song.save!
      ChangeLog.record_update!(resource: song_resource, record: song, actor_name:)
      true
    end

    def normalized_url_attributes(row)
      URL_COLUMNS.index_with { |column| row[column].to_s.strip }
    end

    def resolve_original_songs(text, row_number, errors)
      resolve_original_song_entries(text, row_number, errors).filter_map { |entry| entry.fetch(:original_song) }
    end

    def resolve_original_song_entries(text, row_number, errors)
      queries = original_song_queries(text)
      return [] if queries.blank?

      queries.map do |query|
        candidates = original_songs_by_normalized_title[normalize_original_song_title(query)]
        if candidates.blank?
          error = "#{row_number}行目: 原曲「#{query}」が見つかりません。"
          errors << error
          next({ query:, original_song: nil, error: })
        end
        if candidates.many?
          error = "#{row_number}行目: 原曲「#{query}」が複数候補に一致しました。"
          errors << error
          next({ query:, original_song: nil, error: })
        end

        { query:, original_song: candidates.first, error: nil }
      end
    end

    def original_song_resolution_item(entry)
      original_song = entry.fetch(:original_song)

      {
        input_title: entry.fetch(:query),
        title: original_song&.title || entry.fetch(:query),
        exists: original_song.present?,
        error: entry.fetch(:error)&.sub(/\A1行目: /, '')
      }
    end

    def original_song_queries(text)
      normalized_text = text.to_s.strip.sub(/\A原曲[:：]\s*/, '')
      return [] if normalized_text.blank?
      return [normalized_text] if known_original_song_title?(normalized_text)

      split_original_song_queries(normalized_text)
    end

    def split_original_song_queries(text)
      tokens = text.split(%r{([/／,，、])}).compact_blank
      queries = []
      index = 0

      while index < tokens.size
        if original_song_delimiter?(tokens[index])
          index += 1
          next
        end

        best_end = longest_known_title_end(tokens, index)
        if best_end
          queries << tokens[index..best_end].join.strip
          index = best_end + 1
          index += 1 if original_song_delimiter?(tokens[index])
          next
        end

        queries << tokens[index].strip
        index += 1
      end

      queries.compact_blank
    end

    def longest_known_title_end(tokens, start_index)
      best_end = nil
      current = +''

      (start_index...tokens.size).each do |index|
        current << tokens[index]
        best_end = index if known_original_song_title?(current.strip)
      end

      best_end
    end

    def original_song_delimiter?(token)
      return false if token.nil?

      token.match?(%r{\A[/／,，、]\z})
    end

    def known_original_song_title?(title)
      original_songs_by_normalized_title.key?(normalize_original_song_title(title))
    end

    def original_songs_by_normalized_title
      @original_songs_by_normalized_title ||= grouped_original_songs_by_normalized_title
    end

    def grouped_original_songs_by_normalized_title
      OriginalSong
        .non_duplicated
        .order(:code)
        .to_a
        .group_by { |original_song| normalize_original_song_title(original_song.title) }
    end

    def normalize_original_song_title(title)
      self.class.normalize_original_song_title(title)
    end
  end
end
