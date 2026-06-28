require 'csv'

module Admin
  module Operations
    class SongTsvOperation < BaseOperation
      SONG_EXPORT_COLUMNS = %w[
        id karaoke_type display_artist_name title original_songs youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url
      ].freeze

      def initialize(params:, scope:)
        super()
        @params = params
        @scope = scope
      end

      def export_songs
        songs = @scope.includes(:display_artist, :original_songs)
        download(generate_songs_tsv(songs), 'songs.tsv')
      end

      def export_missing_original_songs
        songs = Song
                .includes(:display_artist, :original_songs)
                .missing_original_songs
                .left_outer_joins(:display_artist)
                .order('display_artists.name asc')
                .order(title: :asc)

        download(generate_songs_tsv(songs), 'missing_original_songs.tsv')
      end

      def import_songs_with_original_songs
        uploaded_file = @params.dig(:operation_fields, :tsv_file)
        raise ArgumentError, 'TSVファイルを指定してください。' unless uploaded_file.respond_to?(:path)
        raise ArgumentError, 'TSVファイルを指定してください。' unless tsv_file?(uploaded_file)

        imported_count = 0
        skipped_count = 0

        CSV.table(uploaded_file.path, col_sep: "\t", converters: nil, liberal_parsing: true).each do |row|
          song = Song.find_by(id: row[:id])
          original_song_titles = row[:original_songs].to_s.split('/').compact_blank

          if song.blank? || original_song_titles.blank?
            skipped_count += 1
            next
          end

          song.original_songs = OriginalSong.where(title: original_song_titles, is_duplicate: false)
          song.assign_attributes(
            youtube_url: row[:youtube_url].to_s,
            nicovideo_url: row[:nicovideo_url].to_s,
            apple_music_url: row[:apple_music_url].to_s,
            youtube_music_url: row[:youtube_music_url].to_s,
            spotify_url: row[:spotify_url].to_s,
            line_music_url: row[:line_music_url].to_s
          )
          song.save!
          imported_count += 1
        end

        message("インポートが完了しました。更新件数: #{imported_count}件、スキップ件数: #{skipped_count}件")
      end

      private

      def generate_songs_tsv(songs)
        CSV.generate(col_sep: "\t") do |csv|
          csv << SONG_EXPORT_COLUMNS
          songs.each do |song|
            csv << [
              song.id,
              song.karaoke_type,
              song.display_artist.name,
              song.title,
              song.original_songs.map(&:title).join('/'),
              song.youtube_url,
              song.nicovideo_url,
              song.apple_music_url,
              song.youtube_music_url,
              song.spotify_url,
              song.line_music_url
            ]
          end
        end
      end

      def tsv_file?(uploaded_file)
        uploaded_file.content_type.in?(%w[text/tab-separated-values text/plain]) || uploaded_file.original_filename.ends_with?('.tsv')
      end
    end
  end
end
