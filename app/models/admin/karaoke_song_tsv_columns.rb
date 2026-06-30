# frozen_string_literal: true

module Admin
  module KaraokeSongTsvColumns
    LABELS = {
      'id' => '楽曲ID',
      'karaoke_type' => 'カラオケ種別',
      'display_artist_name' => 'アーティスト名',
      'title' => 'タイトル',
      'original_songs' => '原曲',
      'youtube_url' => 'YouTube URL',
      'nicovideo_url' => 'ニコニコ動画 URL',
      'apple_music_url' => 'Apple Music URL',
      'youtube_music_url' => 'YouTube Music URL',
      'spotify_url' => 'Spotify URL',
      'line_music_url' => 'LINE MUSIC URL'
    }.freeze
    KEYS_BY_LABEL = LABELS.invert.freeze

    module_function

    def label(column)
      LABELS.fetch(column.to_s, column.to_s.humanize)
    end

    def labels(columns)
      columns.map { |column| label(column) }
    end

    def key(header)
      header_text = header.to_s
      return header_text if LABELS.key?(header_text)

      KEYS_BY_LABEL[header_text]
    end

    def missing_columns(headers, required_columns)
      normalized_headers = headers.compact.filter_map { |header| key(header) }
      required_columns - normalized_headers
    end

    def normalized_row(row, required_columns)
      headers_by_key = row.headers.compact.index_by { |header| key(header) }
      required_columns.index_with do |column|
        header = headers_by_key[column]
        header ? row[header] : nil
      end
    end
  end
end
