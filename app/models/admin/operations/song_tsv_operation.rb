require 'csv'

module Admin
  module Operations
    class SongTsvOperation < BaseOperation
      SONG_EXPORT_COLUMNS = %w[
        id karaoke_type display_artist_name title original_songs youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url
      ].freeze
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

      def initialize(resource:, operation:, params:, scope:)
        super()
        @resource = resource
        @operation = operation
        @params = params
        @scope = scope
      end

      def export_songs
        songs = operation_scope.includes(:display_artist, :original_songs)
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
        raise OperationRunner::InputError, 'TSVファイルを指定してください。' unless uploaded_file.respond_to?(:path)
        raise OperationRunner::InputError, 'TSVファイルを指定してください。' unless tsv_file?(uploaded_file)

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

      attr_reader :operation, :params, :scope

      def operation_scope
        ids = selected_ids
        raise OperationRunner::InputError, '対象を選択してください。' if operation.selection == :required && ids.blank?
        return scope if ids.blank? && !selected_ids_submitted?
        return scope.none if ids.blank?

        scope.where(@resource.model.primary_key => ids)
      end

      def selected_ids_submitted?
        params.key?(:selected_ids) || params.key?('selected_ids')
      end

      def selected_ids
        raw_ids = Array(params[:selected_ids]).map(&:to_s).compact_blank.uniq
        return [] if raw_ids.blank?
        return raw_ids unless uuid_primary_key?

        raw_ids.grep(UUID_PATTERN)
      end

      def uuid_primary_key?
        @resource.model.columns_hash.fetch(@resource.model.primary_key).type == :uuid
      end

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
