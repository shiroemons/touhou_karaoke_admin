# frozen_string_literal: true

module Admin
  module Operations
    class SongIntegrityOperation < BaseOperation
      def initialize(params:, scope:)
        super()
        @params = params
        @scope = scope
      end

      def reconcile_joysound_song_duplicates(progress: nil)
        dry_run = dry_run?
        result = DataIntegrity::SongDuplicateReconciler.new(
          scope: @scope.where(karaoke_type: DataIntegrity::SongDuplicateReconciler::KARAOKE_TYPE),
          dry_run:,
          progress:
        ).call

        raise StandardError, result[:errors].join("\n") if result[:errors].any?

        action = dry_run ? '整理対象を確認しました' : '重複曲を整理しました'
        song_count = dry_run ? result[:songs_to_delete] : result[:songs_deleted]
        artist_count = dry_run ? result[:artists_to_update] : result[:artists_updated]
        orphan_count = dry_run ? result[:orphan_artists_to_delete] : result[:orphan_artists_deleted]
        skipped_count = result[:skipped]
        prefix = dry_run ? 'プレビューのみ実行しました。DBは変更していません。' : ''
        message(
          "#{prefix}#{action}。重複グループ: #{result[:checked]}件、" \
          "#{dry_run ? '整理可能' : '整理済み'}: #{result[:reconciled]}件、" \
          "#{dry_run ? '削除予定曲' : '削除曲'}: #{song_count}件、" \
          "#{dry_run ? '更新予定アーティスト' : '更新アーティスト'}: #{artist_count}件、" \
          "#{dry_run ? '削除予定の孤立アーティスト' : '削除した孤立アーティスト'}: #{orphan_count}件、" \
          "保留: #{skipped_count}件"
        )
      end

      private

      def dry_run?
        ActiveModel::Type::Boolean.new.cast(@params.dig(:operation_fields, :dry_run))
      end
    end
  end
end
