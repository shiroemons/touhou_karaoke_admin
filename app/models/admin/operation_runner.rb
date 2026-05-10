require 'csv'

module Admin
  class OperationRunner
    Result = Data.define(:message, :download_data, :download_filename, :download_content_type)

    SONG_EXPORT_COLUMNS = %w[
      id karaoke_type display_artist_name title original_songs youtube_url nicovideo_url apple_music_url youtube_music_url spotify_url line_music_url
    ].freeze
    DISPLAY_ARTIST_EXPORT_COLUMNS = %w[id name karaoke_type url].freeze

    def initialize(resource:, operation:, record:, params:, scope:)
      @resource = resource
      @operation = operation
      @record = record
      @params = params
      @scope = scope
      @progress_id = params[:operation_progress_id]
    end

    def run
      OperationProgress.start!(progress_id, label: operation.label)
      result = operation.handler.blank? ? run_method_operation : run_handler_operation

      OperationProgress.complete!(progress_id, label: '処理が完了しました')
      result
    rescue StandardError => e
      OperationProgress.fail!(progress_id, message: e.message)
      raise
    end

    def export_songs
      songs = operation_scope.includes(:display_artist, :original_songs)
      tsv = generate_songs_tsv(songs)

      download(tsv, 'songs.tsv')
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
      uploaded_file = params.dig(:operation_fields, :tsv_file)
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

    def fetch_dam_song(progress: nil)
      url = params.dig(:operation_fields, :dam_song_url).to_s
      raise ArgumentError, 'DAMの楽曲URLではありません。' unless url.start_with?(Constants::Karaoke::Dam::SONG_URL)

      progress&.call(percentage: 25, status: 'DAM楽曲取得中', label: '指定URLからDAM楽曲を取得しています', detail: nil)
      DamSong.fetch_dam_song(url)
      progress&.call(percentage: 96, status: 'DAM楽曲取得中', label: 'DAM楽曲の保存が完了しました', detail: nil)
      message('DAM楽曲を取得しました。')
    end

    def fetch_joysound_detail(progress: nil)
      url = params.dig(:operation_fields, :joysound_url).to_s
      raise ArgumentError, 'JOYSOUNDの楽曲URLではありません。' unless url.start_with?("#{Constants::Karaoke::Joysound::SEARCH_URL}/")

      progress&.call(percentage: 25, status: 'JOYSOUND詳細取得中', label: '指定URLからJOYSOUND詳細を取得しています', detail: nil)
      JoysoundSong.fetch_joysound_song_direct(url:)
      progress&.call(percentage: 96, status: 'JOYSOUND詳細取得中', label: 'JOYSOUND詳細の保存が完了しました', detail: nil)
      message('JOYSOUND詳細を取得しました。')
    end

    def fetch_joysound_music_post_song(progress: nil)
      result = JoysoundMusicPostManager.new.fetch_songs_with_progress(progress:)
      if result[:errors].any?
        message("取得処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。取得件数: #{result[:fetched]}件")
      else
        message("取得処理が正常に完了しました。取得件数: #{result[:fetched]}件、スキップ件数: #{result[:skipped]}件")
      end
    end

    def refresh_joysound_music_post_song(progress: nil)
      result = JoysoundMusicPostManager.new.refresh_songs_efficiently(progress:)
      if result[:errors].any?
        message("更新処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。削除件数: #{result[:deleted]}件")
      else
        message("更新処理が正常に完了しました。確認件数: #{result[:total_checked]}件、削除件数: #{result[:deleted]}件")
      end
    end

    def update_joysound_music_post_delivery_deadline_dates(progress: nil)
      result = JoysoundMusicPostManager.new.update_delivery_deadlines_optimized(progress:)
      if result[:errors].any?
        message("更新処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。更新件数: #{result[:updated]}件")
      else
        message("更新処理が正常に完了しました。処理件数: #{result[:total_processed]}件、更新件数: #{result[:updated]}件")
      end
    end

    def validate_display_artist_urls(progress: nil)
      result = DisplayArtistUrlValidator.new(delete_invalid: false, progress:).validate_all

      raise StandardError, result[:errors].join("\n") if result[:errors].any?

      if result[:invalid_records].empty?
        message("URL検証が完了しました。確認件数: #{result[:checked]}件、無効なURLはありませんでした。")
      else
        download(generate_display_artists_tsv(result[:invalid_records]), 'invalid_display_artists.tsv')
      end
    end

    def cleanup_invalid_display_artists(progress: nil)
      result = DisplayArtistUrlValidator.new(delete_invalid: true, progress:).validate_all

      raise StandardError, result[:errors].join("\n") if result[:errors].any?

      if result[:deleted_records].any?
        download(generate_display_artists_tsv(result[:deleted_records]), 'deleted_display_artists.tsv')
      else
        skipped_count = result[:invalid] - result[:deleted]
        summary = "検証が完了しました。確認件数: #{result[:checked]}件、無効URL: #{result[:invalid]}件、削除件数: #{result[:deleted]}件"
        summary += "。#{skipped_count}件は関連するsongsがあるため削除されませんでした。" if skipped_count.positive?
        message(summary)
      end
    end

    def cleanup_orphan_display_artists(progress: nil)
      records = DisplayArtist.where.missing(:songs)
      return message('削除対象のレコードはありませんでした。') if records.empty?

      total_count = records.count
      progress&.call(percentage: 8, status: '孤立アーティスト削除中', label: '楽曲が紐づいていないアーティストを削除しています', detail: "処理済み: 0/#{total_count}件", current: 0, total: total_count)
      deleted_records = records.map do |record|
        {
          id: record.id,
          name: record.name,
          karaoke_type: record.karaoke_type,
          url: record.url
        }
      end
      records.find_each.with_index(1) do |record, index|
        record.destroy!
        next unless (index % 10).zero? || index == total_count

        progress&.call(
          percentage: (8 + (88 * (index.to_f / total_count))).floor.clamp(8, 96),
          status: '孤立アーティスト削除中',
          label: '楽曲が紐づいていないアーティストを削除しています',
          detail: "処理済み: #{index}/#{total_count}件",
          current: index,
          total: total_count
        )
      end

      download(generate_display_artists_tsv(deleted_records), 'deleted_orphan_display_artists.tsv')
    end

    def cleanup_expired_joysound_music_posts(progress: nil)
      result = JoysoundMusicPostCleaner.new(progress:).cleanup_expired_records
      raise StandardError, result[:errors].join("\n") if result[:errors].any?

      message("クリーンアップが完了しました。確認件数: #{result[:checked]}件、削除件数: #{result[:deleted]}件")
    end

    def perform_full_joysound_music_post_maintenance(progress: nil)
      results = JoysoundMusicPostManager.new.perform_full_maintenance(progress:)
      summary = [
        "統合メンテナンスが完了しました:",
        "期限切れクリーンアップ: #{results[:cleanup][:deleted]}件削除",
        "楽曲取得: #{results[:fetch][:fetched]}件取得",
        "URL確認: #{results[:refresh][:deleted]}件削除",
        "配信期限更新: #{results[:update_deadlines][:updated]}件更新"
      ].join("\n")
      total_errors = results.values.sum { |result| result[:errors]&.count || 0 }

      summary += "\n#{total_errors}件のエラーが発生しました。詳細はログを確認してください。" if total_errors.positive?
      message(summary)
    end

    private

    attr_reader :operation, :record, :params, :scope, :progress_id

    def operation_scope
      ids = selected_ids
      raise ArgumentError, '対象を選択してください。' if operation.selection == :required && ids.blank?
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

      raw_ids.select { |id| id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i) }
    end

    def uuid_primary_key?
      @resource.model.columns_hash.fetch(@resource.model.primary_key).type == :uuid
    end

    def run_method_operation
      target = record || operation_target
      operation_method = target.method(operation.method_name)
      if operation_method.parameters.any? { |type, name| type == :key && name == :progress }
        target.public_send(operation.method_name, progress: method_progress)
      else
        target.public_send(operation.method_name)
      end
      message("#{operation.label}を実行しました。")
    end

    def run_handler_operation
      handler_method = method(operation.handler)
      if handler_method.parameters.any? { |type, name| type == :key && name == :progress }
        public_send(operation.handler, progress: method_progress)
      else
        public_send(operation.handler)
      end
    end

    def method_progress
      lambda do |**attributes|
        OperationProgress.update!(progress_id, **attributes)
      end
    end

    def operation_target
      @resource.model
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

    def generate_display_artists_tsv(records)
      CSV.generate(col_sep: "\t") do |csv|
        csv << DISPLAY_ARTIST_EXPORT_COLUMNS
        records.each do |record|
          csv << [record[:id], record[:name], record[:karaoke_type], record[:url]]
        end
      end
    end

    def tsv_file?(uploaded_file)
      uploaded_file.content_type.in?(%w[text/tab-separated-values text/plain]) || uploaded_file.original_filename.ends_with?('.tsv')
    end

    def message(text)
      Result.new(message: text, download_data: nil, download_filename: nil, download_content_type: nil)
    end

    def download(data, filename)
      Result.new(
        message: "#{filename}を生成しました。",
        download_data: data,
        download_filename: filename,
        download_content_type: 'text/tab-separated-values; charset=utf-8'
      )
    end
  end
end
