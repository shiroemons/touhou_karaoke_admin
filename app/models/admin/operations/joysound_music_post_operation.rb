module Admin
  module Operations
    class JoysoundMusicPostOperation < BaseOperation
      def initialize(params:)
        super()
        @params = params
      end

      def fetch_joysound_music_post_song(progress: nil)
        result = JoysoundMusicPostManager.new.fetch_songs_with_progress(progress:)
        if result[:errors].any?
          message("取得処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。取得件数: #{result[:fetched]}件")
        else
          message("取得処理が正常に完了しました。取得件数: #{result[:fetched]}件、スキップ件数: #{result[:skipped]}件")
        end
      end

      alias register_joysound_music_post_songs fetch_joysound_music_post_song

      def refresh_joysound_music_post_song(progress: nil)
        result = JoysoundMusicPostManager.new.refresh_songs_efficiently(progress:)
        if result[:errors].any?
          message("更新処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。削除件数: #{result[:deleted]}件")
        else
          message("更新処理が正常に完了しました。確認件数: #{result[:total_checked]}件、削除件数: #{result[:deleted]}件")
        end
      end

      alias verify_joysound_music_post_songs refresh_joysound_music_post_song

      def update_joysound_music_post_delivery_deadline_dates(progress: nil)
        result = JoysoundMusicPostManager.new.update_delivery_deadlines_optimized(progress:)
        if result[:errors].any?
          message("更新処理が完了しましたが、#{result[:errors].count}件のエラーが発生しました。更新件数: #{result[:updated]}件")
        else
          message("更新処理が正常に完了しました。処理件数: #{result[:total_processed]}件、更新件数: #{result[:updated]}件")
        end
      end

      alias sync_joysound_music_post_delivery_deadlines update_joysound_music_post_delivery_deadline_dates

      def cleanup_expired_joysound_music_posts(progress: nil)
        dry_run = dry_run?
        result = JoysoundMusicPostCleaner.new(dry_run:, progress:).cleanup_expired_records
        raise StandardError, result[:errors].join("\n") if result[:errors].any?

        summary = destructive_summary(dry_run, "クリーンアップが完了しました。確認件数: #{result[:checked]}件、#{deletion_count_label(dry_run)}: #{result[:deleted]}件")
        summary += "。対象例: #{joysound_music_post_preview_labels(result[:deleted_records])}" if dry_run && result[:deleted_records].present?
        message(summary)
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

      alias run_full_joysound_music_post_maintenance perform_full_joysound_music_post_maintenance

      private

      def dry_run?
        ActiveModel::Type::Boolean.new.cast(@params.dig(:operation_fields, :dry_run))
      end

      def destructive_summary(dry_run, text)
        dry_run ? "プレビューのみ実行しました。DBは変更していません。#{text}" : text
      end

      def deletion_count_label(dry_run)
        dry_run ? '削除予定件数' : '削除件数'
      end

      def joysound_music_post_preview_labels(records)
        records.first(5).map { |record| "#{record[:artist]} - #{record[:title]}" }.join(' / ')
      end
    end
  end
end
